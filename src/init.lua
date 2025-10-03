local Driver = require "st.driver"
local caps = require "st.capabilities"
local log = require "log"
local socket = require "socket"
local json = require "dkjson" -- Twinkly UDP payload is JSON
local twinkly = require "twinkly"

-- helper to resolve IP address
local function resolve_ip(device, explicit_ip)
  if explicit_ip and explicit_ip ~= "" then
    return explicit_ip
  else
    return device.preferences.ipAddress or device:get_field("ipAddress")
  end
end

-- switch handlers
local function switch_on(driver, device, command)
  local ip = resolve_ip(device)
  log.info("ON -> " .. (ip or "?"))
  if ip then
    twinkly.set_mode(ip, "movie")
    device:emit_event(caps.switch.switch.on())
  end
end

local function switch_off(driver, device, command)
  local ip = resolve_ip(device)
  log.info("OFF -> " .. (ip or "?"))
  if ip then
    twinkly.set_mode(ip, "off")
    device:emit_event(caps.switch.switch.off())
  end
end

local function handle_refresh(driver, device, command)
  local ip = resolve_ip(device)
  log.info("REFRESH -> " .. (ip or "?"))
  if not ip then return end
  local ok, mode = pcall(twinkly.get_mode, ip)
  if ok then
    if mode == "movie" then
      device:emit_event(caps.switch.switch.on())
    elseif mode == "off" then
      device:emit_event(caps.switch.switch.off())
    end
  else
    log.warn("Failed to refresh " .. (ip or "?"))
  end
end

-- poll state from Twinkly
local function poll_state(driver, device)
  local ip = resolve_ip(device)
  if not ip then return end
  local ok, mode = pcall(twinkly.get_mode, ip)
  if ok then
    if mode == "movie" then
      device:emit_event(caps.switch.switch.on())
    elseif mode == "off" then
      device:emit_event(caps.switch.switch.off())
    end
  else
    log.warn("Failed to poll " .. (ip or "?"))
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

  -- schedule polling according to preference (seconds)
  local interval = tonumber(device.preferences.pollInterval) or 30
  if interval >= 5 then
    local timer = driver.call_on_schedule(driver, interval, function() poll_state(driver, device) end)
    device:set_field("poll_timer", timer)
  end
end

local function device_added(driver, device)
  log.info("Device added: " .. (device.device_network_id or "unknown"))
  device:emit_event(caps.switch.switch.off())
  log.info("Placeholder Twinkly device created. Please set the IP address in preferences.")
end

local function device_info_changed(driver, device)
  device_init(driver, device)
end

-- discovery: listen for UDP broadcasts on 5555 for a short window
local function discovery(driver, opts, cons)
  log.info("Starting Twinkly discovery...")
  local udp = assert(socket.udp())
  local ok, err = udp:setsockname("*", 5555)
  if not ok then
    log.error("Failed to bind UDP socket: " .. tostring(err))
    return
  end
  udp:settimeout(0.5)

  local start = os.time()
  while os.time() - start < 10 do
    local data, ip = udp:receivefrom()
    if data and ip then
      log.info("Discovered Twinkly broadcast from " .. ip)

      local info = nil
      pcall(function() info = json.decode(data) end)

      local mac = info and info.mac or ip -- fallback to IP if no MAC
      local label = "Twinkly " .. (info and info.device_name or ip)

      -- prevent duplicate devices
      local exists = false
      for _, dev in pairs(driver:get_devices()) do
        if dev.device_network_id == mac then
          exists = true
          break
        end
      end

      if not exists then
        log.info("Creating new device: " .. label .. " (" .. mac .. ")")
        driver:try_create_device({
          type = "LAN",
          device_network_id = mac,
          label = label,
          profile = "twinkly-switch",
          manufacturer = "Twinkly",
          model = "LED",
        })
      else
        log.info("Device " .. mac .. " already exists, updating IP")
        local dev = driver:get_device_info(mac)
        if dev then
          dev:set_field("ipAddress", ip, { persist = true })
        end
      end
    end
  end
  udp:close()
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