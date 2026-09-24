local Driver = require "st.driver"
local caps = require "st.capabilities"
local api = require "twinkly.api"
local discovery = require "twinkly.discovery"
local scenes = require "twinkly.scenes"
local log = require "log"

local MODE = "/xled/v1/led/mode"
local BRIGHTNESS = "/xled/v1/led/out/brightness"
local COLOR = "/xled/v1/led/color"
local POLL_INTERVAL = 60
local REDISCOVERY_INTERVAL = 30
local COLOR_DELAY = 0.15
local LEVEL_DELAY = 0.12

local function finite_number(value)
  return type(value) == "number" and value == value and
    value ~= math.huge and value ~= -math.huge
end

local function valid_ip(ip)
  if type(ip) ~= "string" then return false end
  local a, b, c, d = ip:match("^(%d+)%.(%d+)%.(%d+)%.(%d+)$")
  if not a then return false end
  for _, part in ipairs({ a, b, c, d }) do
    if tonumber(part) > 255 then return false end
  end
  return ip ~= "0.0.0.0"
end

local function auto_ip(ip)
  return ip == nil or ip == "" or ip == "0.0.0.0"
end

local function ip_for(device)
  local ip = device:get_field("ipAddress")
  local pref = device.preferences and device.preferences.ipAddress
  -- A configured preference is an explicit manual address override.
  if valid_ip(pref) then ip = pref end
  if valid_ip(ip) then return ip end
  if valid_ip(pref) then return pref end
  return nil
end

local function invoke(device, path, method, payload)
  local ip = ip_for(device)
  if not ip then log.warn("Twinkly has no IP address: " .. tostring(device.id)); return nil end
  local result, err = api.call(ip, path, method, payload)
  if not result then log.warn("Twinkly " .. path .. " failed: " .. tostring(err)) end
  return result, err
end

local function remember_mode(device, mode)
  if mode ~= "movie" and mode ~= "demo" and mode ~= "color" and mode ~= "effect" then return end
  if device:get_field("last_on_mode") ~= mode then
    device:set_field("last_on_mode", mode, { persist = true })
  end
end

local function refresh(driver, device)
  local old_ip = ip_for(device)
  local mode = invoke(device, MODE)
  if not mode and driver and not valid_ip(device.preferences and device.preferences.ipAddress) then
    local now = os.time()
    local previous = device:get_field("last_rediscovery")
    if not previous or now < previous or now - previous >= REDISCOVERY_INTERVAL then
      device:set_field("last_rediscovery", now)
      local scanned, err = discovery.scan(driver, false)
      if not scanned then log.warn("Twinkly rediscovery failed: " .. tostring(err)) end
      if ip_for(device) ~= old_ip then mode = invoke(device, MODE) end
    end
  end
  if not mode or type(mode.mode) ~= "string" then return end
  if mode.mode ~= "color" and not device:get_field("color_busy") and
    not device:get_field("queued_color") then
    device:set_field("desired_color", nil)
  end
  remember_mode(device, mode.mode)
  if mode.mode == "demo" or mode.mode == "effect" or mode.mode == "movie" then
    local scene = scenes.current(function(path, method, payload)
      return invoke(device, path, method, payload)
    end, mode.mode)
    if scene and device:get_field("last_scene") ~= scene then
      device:set_field("last_scene", scene, { persist = true })
    end
  elseif mode.mode == "color" and device:get_field("last_scene") then
    device:set_field("last_scene", nil, { persist = true })
  end
  device:emit_event(mode.mode == "off" and caps.switch.switch.off() or caps.switch.switch.on())
  if device.profile.name == "twinkly-color-light" or device.profile.name == "twinkly-dimmer" then
    local brightness
    if not device:get_field("level_busy") and not device:get_field("queued_level") then
      brightness = invoke(device, BRIGHTNESS)
    end
    if brightness then
      local level = brightness.mode == "disabled" and 100 or brightness.value
      if finite_number(level) then
        device:emit_event(caps.switchLevel.level(math.floor(math.max(0, math.min(100, level)) + 0.5)))
      end
    end
    if device.profile.name == "twinkly-color-light" and mode.mode == "color" and
      not device:get_field("color_busy") and not device:get_field("queued_color") then
      local color = invoke(device, COLOR)
      if color and finite_number(color.hue) and finite_number(color.saturation) then
        local hue = math.floor(math.max(0, math.min(359, color.hue)) / 3.6 + 0.5)
        local saturation = math.floor(math.max(0, math.min(255, color.saturation)) / 2.55 + 0.5)
        if not device:get_field("color_busy") and not device:get_field("queued_color") then
          device:set_field("desired_color", { hue = hue, saturation = saturation })
        end
        device:emit_event(caps.colorControl.hue(hue))
        device:emit_event(caps.colorControl.saturation(saturation))
      end
    end
  end
  return true
end

local function set_mode(_, device, mode)
  local result = invoke(device, MODE, "POST", { mode = mode })
  if result then device:emit_event(mode == "off" and caps.switch.switch.off() or caps.switch.switch.on()) end
end

local function cancel_color(driver, device)
  local timer = device:get_field("color_timer")
  if timer then driver:cancel_timer(timer) end
  device:set_field("color_timer", nil)
  device:set_field("queued_color", nil)
  device:set_field("desired_color", nil)
  device:set_field("color_generation", (device:get_field("color_generation") or 0) + 1)
end

local function cancel_level(driver, device)
  local timer = device:get_field("level_timer")
  if timer then driver:cancel_timer(timer) end
  device:set_field("level_timer", nil)
  device:set_field("queued_level", nil)
  device:set_field("level_generation", (device:get_field("level_generation") or 0) + 1)
end

local function activate_scene(driver, device, scene)
  local result, canonical_or_error, failure_kind = scenes.activate(function(path, method, payload)
    return invoke(device, path, method, payload)
  end, scene)
  if not result then
    log.warn("Twinkly scene " .. tostring(scene) .. " failed: " .. tostring(canonical_or_error))
    if failure_kind == "uncertain" then refresh(driver, device) end
    if (failure_kind == "invalid" or failure_kind == "unavailable") and
      device:get_field("pending_scene") == scene then
      device:set_field("pending_scene", nil, { persist = true })
    end
    return false, failure_kind
  end
  if device:get_field("last_scene") ~= canonical_or_error then
    device:set_field("last_scene", canonical_or_error, { persist = true })
  end
  remember_mode(device, scene:match("^[^:@]+"))
  if device:get_field("pending_scene") == scene then
    device:set_field("pending_scene", nil, { persist = true })
  end
  device:emit_event(caps.switch.switch.on())
  return true
end

local function poll(driver, device)
  if refresh(driver, device) then
    local pending = device:get_field("pending_scene")
    if pending then activate_scene(driver, device, pending) end
  end
end

local function on(driver, device)
  cancel_color(driver, device)
  cancel_level(driver, device)
  local pending = device:get_field("pending_scene")
  if pending then
    local ok, failure_kind = activate_scene(driver, device, pending)
    if ok or failure_kind == "retry" or failure_kind == "uncertain" then return ok end
  end
  local scene = device:get_field("last_scene")
  if scene then
    local ok, failure_kind = activate_scene(driver, device, scene)
    if not ok and failure_kind == "unavailable" then
      return activate_scene(driver, device, "demo")
    end
    return ok
  end
  local previous = device:get_field("last_on_mode") or "demo"
  if previous ~= "color" and previous ~= "demo" then previous = "demo" end
  local result = invoke(device, MODE, "POST", { mode = previous })
  if result then
    remember_mode(device, previous)
    device:emit_event(caps.switch.switch.on())
  end
  return result ~= nil
end

local function off(driver, device)
  cancel_color(driver, device)
  cancel_level(driver, device)
  device:set_field("pending_scene", nil, { persist = true })
  set_mode(driver, device, "off")
end

local flush_level
local function schedule_level(driver, device)
  local timer
  timer = driver:call_with_delay(LEVEL_DELAY, function()
    if device:get_field("level_timer") ~= timer then return end
    device:set_field("level_timer", nil)
    flush_level(driver, device)
  end, "twinkly-level-" .. tostring(device.id))
  device:set_field("level_timer", timer)
end

flush_level = function(driver, device)
  if device:get_field("level_busy") then return end
  local value = device:get_field("queued_level")
  if not value then return end
  device:set_field("queued_level", nil)
  device:set_field("level_busy", true)
  local generation = device:get_field("level_generation")
  local result = invoke(device, BRIGHTNESS, "POST", { mode = "enabled", type = "A", value = value })
  if result and device:get_field("level_generation") == generation then
    device:emit_event(caps.switchLevel.level(value))
  end
  device:set_field("level_busy", nil)
  if device:get_field("level_generation") == generation or device:get_field("queued_level") then
    schedule_level(driver, device)
  end
end

local function level(driver, device, command)
  local value = command.args and tonumber(command.args.level)
  if not finite_number(value) then return end
  value = math.max(0, math.min(100, math.floor(value + 0.5)))
  if value == 0 then
    off(driver, device)
    return
  end
  if device:get_latest_state("main", caps.switch.ID, caps.switch.switch.NAME) ~= "on" then
    if not on(driver, device) then return end
  end
  device:set_field("queued_level", value)
  device:set_field("level_generation", (device:get_field("level_generation") or 0) + 1)
  if device:get_field("level_busy") or device:get_field("level_timer") then return end
  flush_level(driver, device)
end

local flush_color
local function schedule_color(driver, device)
  local timer
  timer = driver:call_with_delay(COLOR_DELAY, function()
    if device:get_field("color_timer") ~= timer then return end
    device:set_field("color_timer", nil)
    flush_color(driver, device)
  end, "twinkly-color-" .. tostring(device.id))
  device:set_field("color_timer", timer)
end

flush_color = function(driver, device)
  if device:get_field("color_busy") then return end
  local value = device:get_field("queued_color")
  if not value then return end
  device:set_field("queued_color", nil)
  device:set_field("color_busy", true)
  local generation = device:get_field("color_generation")
  local changed = invoke(device, COLOR, "POST", {
    hue = math.min(359, math.floor(value.hue * 3.6 + 0.5)),
    saturation = math.floor(value.saturation * 2.55 + 0.5),
    value = 255,
  })
  local confirmed = false
  if changed and device:get_field("color_generation") == generation then
    local mode = invoke(device, MODE, "POST", { mode = "color" })
    if mode and device:get_field("color_generation") == generation then
      confirmed = true
      remember_mode(device, "color")
      device:set_field("last_scene", nil, { persist = true })
      device:set_field("pending_scene", nil, { persist = true })
      device:emit_event(caps.colorControl.hue(value.hue))
      device:emit_event(caps.colorControl.saturation(value.saturation))
      device:emit_event(caps.switch.switch.on())
    end
  end
  device:set_field("color_busy", nil)
  if not confirmed and device:get_field("color_generation") == generation and
    not device:get_field("queued_color") then
    device:set_field("desired_color", nil)
  end
  if device:get_field("color_generation") == generation or device:get_field("queued_color") then
    schedule_color(driver, device)
  end
end

local function color(driver, device, command)
  local value = command.args and command.args.color or {}
  if type(value) ~= "table" then return end
  local hue, saturation = tonumber(value.hue), tonumber(value.saturation)
  if not finite_number(hue) or not finite_number(saturation) then return end
  hue = math.max(0, math.min(100, hue))
  saturation = math.max(0, math.min(100, saturation))
  local desired = { hue = hue, saturation = saturation }
  device:set_field("desired_color", desired)
  device:set_field("queued_color", desired)
  device:set_field("color_generation", (device:get_field("color_generation") or 0) + 1)
  if device:get_field("color_busy") or device:get_field("color_timer") then return end
  flush_color(driver, device)
end

local function set_hue(driver, device, command)
  local desired = device:get_field("desired_color")
  local saturation = desired and desired.saturation or device:get_latest_state("main", caps.colorControl.ID,
    caps.colorControl.saturation.NAME) or 100
  color(driver, device, { args = { color = { hue = command.args and command.args.hue,
    saturation = saturation } } })
end

local function set_saturation(driver, device, command)
  local desired = device:get_field("desired_color")
  local hue = desired and desired.hue or device:get_latest_state("main", caps.colorControl.ID,
    caps.colorControl.hue.NAME) or 0
  color(driver, device, { args = { color = { hue = hue,
    saturation = command.args and command.args.saturation } } })
end

local function schedule(driver, device)
  local timer = device:get_field("poll_timer")
  if timer then driver:cancel_timer(timer) end
  local interval = tonumber(device.preferences and device.preferences.pollInterval)
  if not finite_number(interval) then interval = POLL_INTERVAL end
  interval = math.floor(math.max(30, math.min(3600, interval)))
  timer = driver:call_on_schedule(interval, function()
    poll(driver, device)
  end, "twinkly-poll-" .. tostring(device.id))
  device:set_field("poll_timer", timer)
end

local function init(driver, device)
  if not device:get_field("ipAddress") then
    local discovered_ip = discovery.pending_ip(device.device_network_id)
    if discovered_ip then device:set_field("ipAddress", discovered_ip, { persist = true }) end
  end
  poll(driver, device)
  schedule(driver, device)
end

local function info_changed(driver, device, _, args)
  local old_preferences = args and args.old_st_store and args.old_st_store.preferences or {}
  local preferences = device.preferences or {}
  local network_changed = old_preferences.ipAddress ~= preferences.ipAddress or
    old_preferences.pollInterval ~= preferences.pollInterval
  local scene_changed = old_preferences.scene ~= preferences.scene
  if not network_changed and not scene_changed then return end
  if scene_changed then
    cancel_color(driver, device)
    cancel_level(driver, device)
    local pending = preferences.scene
    if pending == "" then pending = nil end
    device:set_field("pending_scene", pending, { persist = true })
  end
  local old_ip = device:get_field("ipAddress")
  if old_preferences.ipAddress ~= preferences.ipAddress then
    device:set_field("last_rediscovery", nil)
  end
  if valid_ip(old_preferences.ipAddress) and auto_ip(preferences.ipAddress) and
    old_ip == old_preferences.ipAddress then
    device:set_field("ipAddress", nil, { persist = true })
  end
  local ip = ip_for(device)
  if old_ip and old_ip ~= ip then api.clear(old_ip) end
  if ip and ip ~= old_ip then device:set_field("ipAddress", ip, { persist = true }); api.clear(ip) end
  if ip ~= old_ip then poll(driver, device) end
  if network_changed then schedule(driver, device) end
  if scene_changed and preferences.scene and preferences.scene ~= "" and
    device:get_field("pending_scene") == preferences.scene then
    activate_scene(driver, device, preferences.scene)
  end
end

local function removed(driver, device)
  cancel_color(driver, device)
  cancel_level(driver, device)
  local timer = device:get_field("poll_timer")
  if timer then driver:cancel_timer(timer) end
  device:set_field("poll_timer", nil)
  local ip = ip_for(device)
  if ip then api.clear(ip) end
end

Driver("twinkly", {
  discovery = function(driver)
    local ok, err = discovery.scan(driver)
    if not ok then log.warn("Twinkly discovery failed: " .. tostring(err)) end
  end,
  lifecycle_handlers = { init = init, infoChanged = info_changed, removed = removed },
  capability_handlers = {
    [caps.switch.ID] = {
      [caps.switch.commands.on.NAME] = on,
      [caps.switch.commands.off.NAME] = off,
    },
    [caps.switchLevel.ID] = { [caps.switchLevel.commands.setLevel.NAME] = level },
    [caps.colorControl.ID] = {
      [caps.colorControl.commands.setColor.NAME] = color,
      [caps.colorControl.commands.setHue.NAME] = set_hue,
      [caps.colorControl.commands.setSaturation.NAME] = set_saturation,
    },
    [caps.refresh.ID] = { [caps.refresh.commands.refresh.NAME] = poll },
  },
}):run()
