local Driver = require "st.driver"
local caps = require "st.capabilities"
local json = require "dkjson" -- Twinkly UDP payload is JSON
local twinkly = require "twinkly"
local ok, log = pcall(require, "log")
if not ok then
  log = {
    debug = function(...) print("[DEBUG]", ...) end,
    info  = function(...) print("[INFO]", ...) end,
    warn  = function(...) print("[WARN]", ...) end,
    error = function(...) print("[ERROR]", ...) end,
  }
end

-- helper: resolve IP from preferences only
local function resolve_ip(device)
  local ip = device.preferences and device.preferences.ipAddress
  if not ip or ip == "" then
    log.warn("No IP address configured for device " .. (device.label or device.id))
    return nil
  end
  return ip
end

-- helper: get latest state value safely
local function latest_value(device, component, capability_id, attribute)
  local st = device:get_latest_state(component, capability_id, attribute)
  if type(st) == "table" then
    return st.value
  end
  return st
end

-- helper: convert hue 0-100 -> degrees 0-360, saturation 0-100 -> 0-1, value 0-100 -> 0-1
local function hsv_params_from_device(h_percent, s_percent, v_percent)
  local h_deg = (tonumber(h_percent) or 0) * 3.6
  local s = (tonumber(s_percent) or 0) / 100
  local v = (tonumber(v_percent) or 100) / 100
  return h_deg, s, v
end

-- simple HSV -> RGB (expects h in degrees 0-360, s/v 0-1), returns ints 0-255
local function hsv_to_rgb(h, s, v)
  local c = v * s
  local x = c * (1 - math.abs(((h / 60) % 2) - 1))
  local m = v - c
  local r1, g1, b1 = 0, 0, 0

  if h < 60 then
    r1, g1, b1 = c, x, 0
  elseif h < 120 then
    r1, g1, b1 = x, c, 0
  elseif h < 180 then
    r1, g1, b1 = 0, c, x
  elseif h < 240 then
    r1, g1, b1 = 0, x, c
  elseif h < 300 then
    r1, g1, b1 = x, 0, c
  else
    r1, g1, b1 = c, 0, x
  end

  local r = math.floor((r1 + m) * 255 + 0.5)
  local g = math.floor((g1 + m) * 255 + 0.5)
  local b = math.floor((b1 + m) * 255 + 0.5)
  return r, g, b
end

-- switch handlers
local function switch_on(driver, device, command)
  local ip = resolve_ip(device)
  log.info("ON -> " .. tostring(ip or "?"))
  if ip and ip ~= "" then
    local ok, result = pcall(twinkly.set_mode, ip, "movie")
    if ok then
      log.info("set_mode returned OK: " .. tostring(result))
      device:emit_event(caps.switch.switch.on())
    else
      log.error("set_mode threw error: " .. tostring(result))
    end
  end
end

local function switch_off(driver, device, command)
  local ip = resolve_ip(device)
  log.info("OFF -> " .. tostring(ip or "?"))
  if ip and ip ~= "" then
    local ok, result = pcall(twinkly.set_mode, ip, "off")
    if ok then
      log.info("set_mode returned OK: " .. tostring(result))
      device:emit_event(caps.switch.switch.off())
    else
      log.error("set_mode threw error: " .. tostring(result))
    end
  end
end

local function handle_refresh(driver, device, command)
  local ip = resolve_ip(device)
  log.info("REFRESH -> " .. tostring(ip or "?"))
  if not ip or ip == "" then
    log.warn("No IP to refresh for device " .. tostring(device.label))
    return
  end

  local ok, mode_or_err = pcall(twinkly.get_mode, ip)
  if ok and mode_or_err then
    local raw = mode_or_err
    if raw ~= "off" then
      device:emit_event(caps.switch.switch.on())
    else
      device:emit_event(caps.switch.switch.off())
    end
  else
    log.warn("Failed to refresh " .. tostring(ip) .. ": " .. tostring(mode_or_err))
  end

  -- refresh brightness and color for color-capable devices
  if device.profile.name and device.profile.name:match("twinkly%-color%-light") then
    -- brightness
    local ok_brightness, brightness = pcall(twinkly.get_brightness, ip)
    if ok_brightness and brightness then
      -- assume brightness returned is 0..255, scale to 0..100
      local level = math.floor((tonumber(brightness) or 0) / 255 * 100)
      device:emit_event(caps.switchLevel.level(level))
    end

    -- color
    local ok_color, color = pcall(twinkly.get_color, ip)
    if ok_color and color and color.red and color.green and color.blue then
      local r, g, b = (color.red or 0) / 255, (color.green or 0) / 255, (color.blue or 0) / 255
      local mx, mn = math.max(r, g, b), math.min(r, g, b)
      local delta = mx - mn
      local h, s, v = 0, 0, mx
      if delta > 0 and mx > 0 then
        s = delta / mx
        if mx == r then
          h = ((g - b) / delta) % 6
        elseif mx == g then
          h = (b - r) / delta + 2
        else
          h = (r - g) / delta + 4
        end
        h = h * 60
      end
      device:emit_event(caps.colorControl.hue(math.floor((h / 360) * 100)))
      device:emit_event(caps.colorControl.saturation(math.floor(s * 100)))
    end
  end
end

-- brightness control handlers (uses fade if available)
local function set_level(driver, device, command)
  local ip = resolve_ip(device)
  local level = tonumber(command.args.level) or 0
  log.info("SET_LEVEL -> " .. tostring(ip or "?") .. " level=" .. tostring(level))

  if ip and ip ~= "" then
    -- current level from device (0..100)
    local current_level = latest_value(device, "main", caps.switchLevel.ID, caps.switchLevel.level.NAME) or 100
    -- convert to 0..255 for Twinkly API
    local from_brightness = math.floor((tonumber(current_level) or 100) / 100 * 255 + 0.5)
    local to_brightness = math.floor(level / 100 * 255 + 0.5)
    local fade_duration = tonumber(device.preferences.fadeDuration) or 800

    local ok, result = pcall(twinkly.fade_brightness, ip, from_brightness, to_brightness, fade_duration)
    if ok and result ~= nil then
      log.info("fade_brightness returned OK: " .. tostring(result))
      device:emit_event(caps.switchLevel.level(level))
    elseif ok then
      -- some implementations return true/no payload
      log.info("fade_brightness returned OK")
      device:emit_event(caps.switchLevel.level(level))
    else
      log.warn("fade_brightness failed, falling back to set_brightness: " .. tostring(result))
      local ok2, r2 = pcall(twinkly.set_brightness, ip, to_brightness)
      if ok2 then
        device:emit_event(caps.switchLevel.level(level))
      else
        log.error("set_brightness fallback failed: " .. tostring(r2))
      end
    end
  end
end

-- color control handlers (fade between colors)
local function set_color(driver, device, command)
  local ip = resolve_ip(device)
  local hue_percent = tonumber(command.args.color and command.args.color.hue) or 0
  local sat_percent = tonumber(command.args.color and command.args.color.saturation) or 0
  log.info("SET_COLOR -> " .. tostring(ip or "?") .. " hue=" .. tostring(hue_percent) .. " sat=" .. tostring(sat_percent))

  if ip and ip ~= "" then
    local fade_duration = tonumber(device.preferences.fadeDuration) or 800

    -- get current RGB from device if possible
    local ok_color, current_color = pcall(twinkly.get_color, ip)
    local cur_r, cur_g, cur_b = 255, 255, 255
    if ok_color and current_color and current_color.red and current_color.green and current_color.blue then
      cur_r, cur_g, cur_b = tonumber(current_color.red), tonumber(current_color.green), tonumber(current_color.blue)
    end

    -- convert target HSV (incoming hue is 0..100) to degrees and fraction
    local h_deg = hue_percent * 3.6
    local s_frac = sat_percent / 100
    local v_frac = (tonumber(latest_value(device, "main", caps.switchLevel.ID, caps.switchLevel.level.NAME)) or 100) / 100

    local target_r, target_g, target_b = hsv_to_rgb(h_deg, s_frac, v_frac)

    -- attempt fade_color
    local ok, result = pcall(twinkly.fade_color, ip, cur_r, cur_g, cur_b, target_r, target_g, target_b, fade_duration)
    if ok then
      log.info("fade_color returned OK: " .. tostring(result))
      device:emit_event(caps.colorControl.hue(hue_percent))
      device:emit_event(caps.colorControl.saturation(sat_percent))
    else
      log.warn("fade_color failed, falling back to set_color_hsv: " .. tostring(result))
      local ok2, r2 = pcall(twinkly.set_color_hsv, ip, h_deg, s_frac * 100, v_frac * 100) -- compatibility fallback
      if ok2 then
        device:emit_event(caps.colorControl.hue(hue_percent))
        device:emit_event(caps.colorControl.saturation(sat_percent))
      else
        log.error("set_color_hsv fallback failed: " .. tostring(r2))
      end
    end
  end
end

local function set_hue(driver, device, command)
  local ip = resolve_ip(device)
  local hue = tonumber(command.args.hue) or 0
  log.info("SET_HUE -> " .. tostring(ip or "?") .. " hue=" .. tostring(hue))

  if ip and ip ~= "" then
    local current_saturation = latest_value(device, "main", caps.colorControl.ID, caps.colorControl.saturation.NAME) or 100
    local current_brightness = latest_value(device, "main", caps.switchLevel.ID, caps.switchLevel.level.NAME) or 100
    -- delegate to set_color with same sat/brightness
    local fake_cmd = { args = { color = { hue = hue, saturation = current_saturation } } }
    return set_color(driver, device, fake_cmd)
  end
end

local function set_saturation(driver, device, command)
  local ip = resolve_ip(device)
  local saturation = tonumber(command.args.saturation) or 0
  log.info("SET_SATURATION -> " .. tostring(ip or "?") .. " sat=" .. tostring(saturation))

  if ip and ip ~= "" then
    local current_hue = latest_value(device, "main", caps.colorControl.ID, caps.colorControl.hue.NAME) or 0
    local fake_cmd = { args = { color = { hue = current_hue, saturation = saturation } } }
    return set_color(driver, device, fake_cmd)
  end
end

-- poll state from Twinkly
local function poll_state(driver, device)
  local ip = resolve_ip(device)
  if not ip or ip == "" then return end

  local ok, mode_or_err = pcall(twinkly.get_mode, ip)
  if ok and mode_or_err then
    if mode_or_err ~= "off" then
      device:emit_event(caps.switch.switch.on())
    else
      device:emit_event(caps.switch.switch.off())
    end
  else
    log.warn("Failed to poll " .. tostring(ip) .. ": " .. tostring(mode_or_err))
  end

  -- Also poll brightness and color for color devices (only when on)
  if device.profile.name and device.profile.name:match("twinkly%-color%-light") and mode_or_err ~= "off" then
    local ok_brightness, brightness = pcall(twinkly.get_brightness, ip)
    if ok_brightness and brightness then
      local level = math.floor((tonumber(brightness) or 0) / 255 * 100)
      device:emit_event(caps.switchLevel.level(level))
    end

    local ok_color, color = pcall(twinkly.get_color, ip)
    if ok_color and color and color.red and color.green and color.blue then
      local r, g, b = (color.red or 0) / 255, (color.green or 0) / 255, (color.blue or 0) / 255
      local mx, mn = math.max(r, g, b), math.min(r, g, b)
      local delta = mx - mn
      local h, s, v = 0, 0, mx
      if delta > 0 and mx > 0 then
        s = delta / mx
        if mx == r then
          h = ((g - b) / delta) % 6
        elseif mx == g then
          h = (b - r) / delta + 2
        else
          h = (r - g) / delta + 4
        end
        h = h * 60
      end
      device:emit_event(caps.colorControl.hue(math.floor((h / 360) * 100)))
      device:emit_event(caps.colorControl.saturation(math.floor(s * 100)))
    end
  end
end

-- lifecycle
local function device_init(driver, device)
  device:emit_event(caps.switch.switch.off())

  -- Initialize brightness and color for color light devices
  if device.profile.name and device.profile.name:match("twinkly%-color%-light") then
    device:emit_event(caps.switchLevel.level(100))
    device:emit_event(caps.colorControl.hue(0))
    device:emit_event(caps.colorControl.saturation(100))
  end

  -- cancel existing timer if present
  local existing = device:get_field("poll_timer")
  if existing then
    driver:cancel_timer(existing)
    device:set_field("poll_timer", nil)
  end

  -- schedule polling according to persisted field (seconds)
  local interval = tonumber(device:get_field("pollInterval")) or 30
  if interval >= 5 then
    local timer = driver.call_on_schedule(driver, interval, function() poll_state(driver, device) end)
    device:set_field("poll_timer", timer)
  end
end

local function device_added(driver, device)
  log.info("Device added: " .. (device.device_network_id or "unknown"))
  device:emit_event(caps.switch.switch.off())

  -- Initialize brightness and color for color light devices
  if device.profile.name and device.profile.name:match("twinkly%-color%-light") then
    device:emit_event(caps.switchLevel.level(100))
    device:emit_event(caps.colorControl.hue(0))
    device:emit_event(caps.colorControl.saturation(100))
  end

  -- ensure persisted fields exist
  if not device:get_field("ipAddress") then
    device:set_field("ipAddress", "", { persist = true })
  end
  if not device:get_field("pollInterval") then
    device:set_field("pollInterval", 30, { persist = true })
  end
  log.info("Placeholder Twinkly device created. Please set the IP address in preferences.")
end

local function device_info_changed(driver, device)
  -- persist preference values to fields so runtime uses fields only
  local pref_ip = device.preferences and device.preferences.ipAddress
  if pref_ip and pref_ip ~= "" then
    device:set_field("ipAddress", pref_ip, { persist = true })
  end
  local pref_poll = device.preferences and device.preferences.pollInterval
  if pref_poll and tonumber(pref_poll) then
    device:set_field("pollInterval", tonumber(pref_poll), { persist = true })
  end

  device_init(driver, device)
end

-- discovery: adds a placeholder device if there are none unconfigured
local function discovery(driver, opts, cons)
  log.info("Twinkly discovery triggered...")

  -- Check if there is already an unconfigured placeholder
  for _, dev in pairs(driver:get_devices()) do
    local ip = dev:get_field("ipAddress")
    if not ip or ip == "" then
      log.info("Unconfigured placeholder exists (" .. dev.device_network_id .. "), skipping new one")
      return
    end
  end

  -- If all devices are configured, create a new placeholder
  local placeholder_id = "twinkly-" .. tostring(os.time())

  driver:try_create_device({
    type = "LAN",
    device_network_id = placeholder_id,
    label = "Twinkly Color Light (" .. placeholder_id .. ")",
    profile = "twinkly-color-light",
    manufacturer = "Twinkly",
    model = "LED",
  })

  log.info("Created new Twinkly placeholder: " .. placeholder_id)
end

local twinkly_driver = Driver("twinkly", {
  discovery = discovery,
  lifecycle_handlers = { init = device_init, added = device_added, infoChanged = device_info_changed },
  capability_handlers = {
    [caps.switch.ID] = {
      [caps.switch.commands.on.NAME] = switch_on,
      [caps.switch.commands.off.NAME] = switch_off,
    },
    [caps.switchLevel.ID] = {
      [caps.switchLevel.commands.setLevel.NAME] = set_level,
    },
    [caps.colorControl.ID] = {
      [caps.colorControl.commands.setColor.NAME] = set_color,
      [caps.colorControl.commands.setHue.NAME] = set_hue,
      [caps.colorControl.commands.setSaturation.NAME] = set_saturation,
    },
    [caps.refresh.ID] = {
      [caps.refresh.commands.refresh.NAME] = handle_refresh,
    }
  }
})

twinkly_driver:run()