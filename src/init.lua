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
  return device:get_field("ipAddress")
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
end

-- lifecycle
local function device_init(driver, device)
  device:emit_event(caps.switch.switch.off())

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
    label = "Twinkly Placeholder (" .. placeholder_id .. ")",
    profile = "twinkly-switch",
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
    [caps.refresh.ID] = {
      [caps.refresh.commands.refresh.NAME] = handle_refresh,
    }
  }
})

twinkly_driver:run()