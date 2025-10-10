local Driver = require "st.driver"
local caps = require "st.capabilities"
local json = require "dkjson"
local twinkly = require "twinkly"
local login = require "twinkly.login"
local socket = require "socket"
local config = require "twinkly.config"

local ok, log = pcall(require, "log")
if not ok then
  log = {
    debug = function(...) print("[DEBUG]", ...) end,
    info  = function(...) print("[INFO]", ...) end,
    warn  = function(...) print("[WARN]", ...) end,
    error = function(...) print("[ERROR]", ...) end,
  }
end

local schedule_poll

-----------------------------------------------------------
-- Resolve IP helper
-----------------------------------------------------------
local function resolve_ip(device)
  local ip = device:get_field("ipAddress")
  if not ip or ip == "" then
    ip = device.preferences.ipAddress
  end
  if not ip or ip == "" then
    log.warn("No IP address configured for device " .. (device.label or device.id))
    return nil
  end
  return ip
end

-----------------------------------------------------------
-- SWITCH HANDLERS
-----------------------------------------------------------
local function switch_on(driver, device, command)
  local ip = resolve_ip(device)
  log.info("ON -> " .. tostring(ip or "?"))
  if ip then
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
  if ip then
    local ok, result = pcall(twinkly.set_mode, ip, "off")
    if ok then
      log.info("set_mode returned OK: " .. tostring(result))
      device:emit_event(caps.switch.switch.off())
    else
      log.error("set_mode threw error: " .. tostring(result))
    end
  end
end

-----------------------------------------------------------
-- REFRESH HANDLER
-----------------------------------------------------------
local function handle_refresh(driver, device, command)
  local ip = resolve_ip(device)
  log.info("REFRESH -> " .. tostring(ip or "?"))
  if not ip then return end

  -- Always ensure we have a valid token before manual refresh
  local token, err = login.ensure_token(ip)
  if not token then
    log.warn(string.format("[refresh] Could not login for %s: %s", ip, tostring(err)))
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

  -- Refresh brightness & color
  if device.profile.name and device.profile.name:match("twinkly%-color%-light") then
    local ok_b, brightness = pcall(twinkly.get_brightness, ip)
    if ok_b and brightness then
      local level = math.floor((brightness / 255) * 100)
      device:emit_event(caps.switchLevel.level(level))
    end

    local ok_c, color = pcall(twinkly.get_color, ip)
    if ok_c and color and color.red then
      local r, g, b = color.red / 255, color.green / 255, color.blue / 255
      local max, min = math.max(r, g, b), math.min(r, g, b)
      local delta = max - min
      local h, s, v = 0, 0, max

      if delta > 0 then
        s = delta / max
        if max == r then
          h = ((g - b) / delta) % 6
        elseif max == g then
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

-----------------------------------------------------------
-- BRIGHTNESS
-----------------------------------------------------------
local function set_level(driver, device, command)
  local ip = resolve_ip(device)
  local level = command.args.level
  log.info(string.format("SET_LEVEL -> %s level=%d", tostring(ip or "?"), level))
  if ip then
    local ok, result = pcall(twinkly.set_brightness, ip, level)
    if ok then
      device:emit_event(caps.switchLevel.level(level))
    else
      log.error("set_brightness failed: " .. tostring(result))
    end
  end
end

-----------------------------------------------------------
-- COLOR CONTROL
-----------------------------------------------------------
local function set_color(driver, device, command)
  local ip = resolve_ip(device)
  local hue = command.args.color.hue or 0
  local sat = command.args.color.saturation or 0
  log.info(string.format("SET_COLOR -> %s hue=%d sat=%d", tostring(ip or "?"), hue, sat))

  if ip then
    local bright = device:get_latest_state("main", caps.switchLevel.ID, caps.switchLevel.level.NAME) or 100
    local ok, result = pcall(twinkly.set_color_hsv, ip, hue, sat, bright)
    if ok then
      device:emit_event(caps.colorControl.hue(hue))
      device:emit_event(caps.colorControl.saturation(sat))
    else
      log.error("set_color_hsv failed: " .. tostring(result))
    end
  end
end

local function set_hue(driver, device, command)
  local ip = resolve_ip(device)
  local hue = command.args.hue
  log.info(string.format("SET_HUE -> %s hue=%d", tostring(ip or "?"), hue))

  if ip then
    local sat = device:get_latest_state("main", caps.colorControl.ID, caps.colorControl.saturation.NAME) or 100
    local bright = device:get_latest_state("main", caps.switchLevel.ID, caps.switchLevel.level.NAME) or 100
    local ok, result = pcall(twinkly.set_color_hsv, ip, hue, sat, bright)
    if ok then
      device:emit_event(caps.colorControl.hue(hue))
    else
      log.error("set_color_hsv failed: " .. tostring(result))
    end
  end
end

local function set_saturation(driver, device, command)
  local ip = resolve_ip(device)
  local sat = command.args.saturation
  log.info(string.format("SET_SAT -> %s sat=%d", tostring(ip or "?"), sat))

  if ip then
    local hue = device:get_latest_state("main", caps.colorControl.ID, caps.colorControl.hue.NAME) or 0
    local bright = device:get_latest_state("main", caps.switchLevel.ID, caps.switchLevel.level.NAME) or 100
    local ok, result = pcall(twinkly.set_color_hsv, ip, hue, sat, bright)
    if ok then
      device:emit_event(caps.colorControl.saturation(sat))
    else
      log.error("set_color_hsv failed: " .. tostring(result))
    end
  end
end

-----------------------------------------------------------
-- POLLING
-----------------------------------------------------------
local function poll_state(driver, device)
  local ip = resolve_ip(device)
  if not ip then return end
  log.debug(string.format("[poll] Polling %s (%s)", device.label or device.id, ip))

  -- Ensure valid token before poll
  local token, err = login.ensure_token(ip)
  if not token then
    log.warn(string.format("[poll] Could not ensure token for %s: %s", ip, tostring(err)))
    return
  end

  -- Try fetching mode (includes color_config sometimes)
  local ok, mode_data = pcall(twinkly.get_mode, ip)
  if not ok or not mode_data then
    log.warn(string.format("[poll] Failed to get mode for %s: %s — retrying once", ip, tostring(mode_data)))
    if socket and socket.sleep then socket.sleep(config.timing.poll_failure_delay) end
    login.clear_token(ip)
    local retry_token = login.ensure_token(ip)
    if retry_token then
      ok, mode_data = pcall(twinkly.get_mode, ip)
    else
      return
    end
  end

  if not ok or not mode_data then
    log.warn(string.format("[poll] Giving up for %s after retry", ip))
    return
  end

  local mode = mode_data.mode or mode_data
  log.debug(string.format("[poll] Current mode for %s: %s", ip, tostring(mode)))
  device:emit_event(mode ~= "off" and caps.switch.switch.on() or caps.switch.switch.off())

  -- Poll brightness & color if light is active
  if device.profile.name and device.profile.name:match("twinkly%-color%-light") and mode ~= "off" then
    local color_cfg = mode_data.color_config
    local new_hue, new_sat, new_brightness

    if color_cfg then
      -- 🎨 Use color_config directly
      local r = color_cfg.red or 0
      local g = color_cfg.green or 0
      local b = color_cfg.blue or 0
      local v = color_cfg.value or 255
      local s = color_cfg.saturation or 255
      local h = color_cfg.hue or 0

      new_brightness = math.floor((v / 255) * 100)
      new_hue = math.floor((h / 360) * 100)
      new_sat = math.floor((s / 255) * 100)

      log.debug(string.format(
        "[poll] Using color_config -> R=%d G=%d B=%d | H=%d S=%d V=%d",
        r, g, b, new_hue, new_sat, new_brightness
      ))
    else
      -- 🕹️ Fallback: old endpoints
      local ok_b, brightness = pcall(twinkly.get_brightness, ip)
      if ok_b and brightness then
        new_brightness = math.floor((brightness / 255) * 100)
      end

      local ok_c, color = pcall(twinkly.get_color, ip)
      if ok_c and color and color.red then
        local r, g, b = color.red / 255, color.green / 255, color.blue / 255
        local max, min = math.max(r, g, b), math.min(r, g, b)
        local delta = max - min
        local h, s, v = 0, 0, max
        if delta > 0 then
          s = delta / max
          if max == r then
            h = ((g - b) / delta) % 6
          elseif max == g then
            h = (b - r) / delta + 2
          else
            h = (r - g) / delta + 4
          end
          h = h * 60
        end
        new_hue = math.floor((h / 360) * 100)
        new_sat = math.floor(s * 100)
      end
    end

    -- 🧠 Smart event deduplication
    local prev_state = device:get_field("last_state") or {}
    local changed = false

    if new_brightness and new_brightness ~= prev_state.brightness then
      device:emit_event(caps.switchLevel.level(new_brightness))
      prev_state.brightness = new_brightness
      changed = true
    end

    if new_hue and new_hue ~= prev_state.hue then
      device:emit_event(caps.colorControl.hue(new_hue))
      prev_state.hue = new_hue
      changed = true
    end

    if new_sat and new_sat ~= prev_state.sat then
      device:emit_event(caps.colorControl.saturation(new_sat))
      prev_state.sat = new_sat
      changed = true
    end

    if changed then
      log.debug(string.format(
        "[poll] Updated color state → hue=%s sat=%s bright=%s",
        tostring(new_hue), tostring(new_sat), tostring(new_brightness)
      ))
      device:set_field("last_state", prev_state, { persist = false })
    else
      log.debug("[poll] No change detected — skipping redundant events")
    end
  end
end

-----------------------------------------------------------
-- LIFECYCLE HANDLERS
-----------------------------------------------------------
local function device_init(driver, device)
  device:emit_event(caps.switch.switch.off())

  if device.profile.name and device.profile.name:match("twinkly%-color%-light") then
    device:emit_event(caps.switchLevel.level(100))
    device:emit_event(caps.colorControl.hue(0))
    device:emit_event(caps.colorControl.saturation(100))
  end

  local existing = device:get_field("poll_timer")
  if existing then
    driver:cancel_timer(existing)
    device:set_field("poll_timer", nil)
  end

  log.info(string.format("Starting polling loop for %s", device.label or device.id))
  poll_state(driver, device)
  schedule_poll(driver, device)
end

local function device_added(driver, device)
  log.info("Device added: " .. (device.device_network_id or "unknown"))
  device:emit_event(caps.switch.switch.off())

  if device.profile.name and device.profile.name:match("twinkly%-color%-light") then
    device:emit_event(caps.switchLevel.level(100))
    device:emit_event(caps.colorControl.hue(0))
    device:emit_event(caps.colorControl.saturation(100))
  end

  if not device:get_field("ipAddress") then
    device:set_field("ipAddress", "", { persist = true })
  end
  if not device:get_field("pollInterval") then
    device:set_field("pollInterval", config.timing.default_poll_interval, { persist = true })
  end

  log.info("Placeholder Twinkly device created. Please set the IP address in preferences.")
end

local function device_info_changed(driver, device)
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

-----------------------------------------------------------
-- DISCOVERY
-----------------------------------------------------------
local function discovery(driver, opts, cons)
  log.info("Twinkly discovery triggered...")

  for _, dev in pairs(driver:get_devices()) do
    local ip = dev:get_field("ipAddress")
    if not ip or ip == "" then
      log.info("Unconfigured placeholder exists (" .. dev.device_network_id .. "), skipping new one")
      return
    end
  end

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

-----------------------------------------------------------
-- SCHEDULE POLLING
-----------------------------------------------------------
function schedule_poll(driver, device)
  local interval = tonumber(device:get_field("pollInterval")) or config.timing.default_poll_interval
  if interval < config.timing.min_poll_interval then interval = config.timing.default_poll_interval end

  local timer = driver:call_with_delay(interval, function()
    poll_state(driver, device)
    schedule_poll(driver, device) -- reschedule continuously
  end)

  device:set_field("poll_timer", timer, { persist = false })
  log.debug(string.format("[schedule_poll] Scheduled polling every %d seconds for %s", interval, device.label or device.id))
end

-----------------------------------------------------------
-- DRIVER DEFINITION
-----------------------------------------------------------
local twinkly_driver = Driver("twinkly", {
  discovery = discovery,
  lifecycle_handlers = {
    init = device_init,
    added = device_added,
    infoChanged = device_info_changed
  },
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