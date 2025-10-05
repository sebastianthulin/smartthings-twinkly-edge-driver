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

-- helper to resolve IP address: only use stored device field (persisted)
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
  
  -- Also refresh brightness and color if device supports it
  if device.profile.name and device.profile.name:match("twinkly%-color%-light") then
    -- Get brightness
    local ok_brightness, brightness = pcall(twinkly.get_brightness, ip)
    if ok_brightness and brightness then
      local level = math.floor((brightness / 255) * 100)
      device:emit_event(caps.switchLevel.level(level))
    end
    
    -- Get color
    local ok_color, color = pcall(twinkly.get_color, ip)
    if ok_color and color and color.red and color.green and color.blue then
      -- Convert RGB to HSV for SmartThings
      local r, g, b = color.red / 255, color.green / 255, color.blue / 255
      local max = math.max(r, g, b)
      local min = math.min(r, g, b)
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

-- brightness control handlers
local function set_level(driver, device, command)
  local ip = resolve_ip(device)
  local level = command.args.level
  log.info("SET_LEVEL -> " .. tostring(ip or "?") .. " level=" .. tostring(level))
  
  if ip and ip ~= "" then
    local ok, result = pcall(twinkly.set_brightness, ip, level)
    if ok then
      log.info("set_brightness returned OK: " .. tostring(result))
      device:emit_event(caps.switchLevel.level(level))
    else
      log.error("set_brightness threw error: " .. tostring(result))
    end
  end
end

-- color control handlers  
local function set_color(driver, device, command)
  local ip = resolve_ip(device)
  local hue = command.args.color.hue or 0
  local saturation = command.args.color.saturation or 0
  log.info("SET_COLOR -> " .. tostring(ip or "?") .. " hue=" .. tostring(hue) .. " sat=" .. tostring(saturation))
  
  if ip and ip ~= "" then
    -- Get current brightness or use default
    local current_brightness = device:get_latest_state("main", caps.switchLevel.ID, caps.switchLevel.level.NAME) or 100
    
    local ok, result = pcall(twinkly.set_color_hsv, ip, hue, saturation, current_brightness)
    if ok then
      log.info("set_color_hsv returned OK: " .. tostring(result))
      device:emit_event(caps.colorControl.hue(hue))
      device:emit_event(caps.colorControl.saturation(saturation))
    else
      log.error("set_color_hsv threw error: " .. tostring(result))
    end
  end
end

local function set_hue(driver, device, command)
  local ip = resolve_ip(device)
  local hue = command.args.hue
  log.info("SET_HUE -> " .. tostring(ip or "?") .. " hue=" .. tostring(hue))
  
  if ip and ip ~= "" then
    -- Get current saturation and brightness
    local current_saturation = device:get_latest_state("main", caps.colorControl.ID, caps.colorControl.saturation.NAME) or 100
    local current_brightness = device:get_latest_state("main", caps.switchLevel.ID, caps.switchLevel.level.NAME) or 100
    
    local ok, result = pcall(twinkly.set_color_hsv, ip, hue, current_saturation, current_brightness)
    if ok then
      log.info("set_color_hsv returned OK: " .. tostring(result))
      device:emit_event(caps.colorControl.hue(hue))
    else
      log.error("set_color_hsv threw error: " .. tostring(result))
    end
  end
end

local function set_saturation(driver, device, command)
  local ip = resolve_ip(device)
  local saturation = command.args.saturation
  log.info("SET_SATURATION -> " .. tostring(ip or "?") .. " sat=" .. tostring(saturation))
  
  if ip and ip ~= "" then
    -- Get current hue and brightness  
    local current_hue = device:get_latest_state("main", caps.colorControl.ID, caps.colorControl.hue.NAME) or 0
    local current_brightness = device:get_latest_state("main", caps.switchLevel.ID, caps.switchLevel.level.NAME) or 100
    
    local ok, result = pcall(twinkly.set_color_hsv, ip, current_hue, saturation, current_brightness)
    if ok then
      log.info("set_color_hsv returned OK: " .. tostring(result))
      device:emit_event(caps.colorControl.saturation(saturation))
    else
      log.error("set_color_hsv threw error: " .. tostring(result))
    end
  end
end

-- poll state from Twinkly
local function poll_state(driver, device)
  local ip = resolve_ip(device)
  log.info(string.format("Polling device %s with IP %s", device.label or device.id, tostring(ip or "?")))
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
  
  -- Also poll brightness and color if device supports it
  if device.profile.name and device.profile.name:match("twinkly%-color%-light") and mode_or_err ~= "off" then
    -- Poll brightness
    local ok_brightness, brightness = pcall(twinkly.get_brightness, ip)
    if ok_brightness and brightness then
      local level = math.floor((brightness / 255) * 100)
      device:emit_event(caps.switchLevel.level(level))
    end
    
    -- Poll color
    local ok_color, color = pcall(twinkly.get_color, ip)
    if ok_color and color and color.red and color.green and color.blue then
      -- Convert RGB to HSV for SmartThings
      local r, g, b = color.red / 255, color.green / 255, color.blue / 255
      local max = math.max(r, g, b)
      local min = math.min(r, g, b)
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

  -- Schedule polling
  local interval = tonumber(device:get_field("pollInterval")) or 30
  if interval > 1 then
    log.info(string.format("Starting poll timer for %s every %d seconds", device.label or device.id, interval))

    -- cancel existing timer if any
    local existing_timer = device:get_field("poll_timer")
    if existing_timer then
      driver:cancel_timer(existing_timer)
      device:set_field("poll_timer", nil)
    end

    -- Use correct API call
    local timer = driver:call_on_schedule(interval, function()
      log.debug(string.format("[poll_timer] Running for %s", device.label or device.id))
      poll_state(driver, device)
    end)

    device:set_field("poll_timer", timer, { persist = false })
  else
    log.warn("Polling interval below minimum threshold; skipping polling")
  end

  poll_state(driver, device)
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