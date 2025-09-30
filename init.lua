local Driver = require "st.driver"
local caps = require "st.capabilities"
local log = require "log"
local socket = require "socket"
local twinkly = require "twinkly"

-- switch handlers
local function switch_on(driver, device, command)
  log.info("ON -> " .. (device.device_network_id or "?"))
  twinkly.set_mode(device.device_network_id, "movie")
  device:emit_event(caps.switch.switch.on())
end

local function switch_off(driver, device, command)
  log.info("OFF -> " .. (device.device_network_id or "?"))
  twinkly.set_mode(device.device_network_id, "off")
  device:emit_event(caps.switch.switch.off())
end

-- poll state from Twinkly
local function poll_state(driver, device)
  local ok, mode = pcall(twinkly.get_mode, device.device_network_id)
  if not ok then
    log.warn("Failed to poll " .. (device.device_network_id or "?"))
    return
  end
  if mode == "movie" then
    device:emit_event(caps.switch.switch.on())
  elseif mode == "off" then
    device:emit_event(caps.switch.switch.off())
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

local function device_info_changed(driver, device)
  device_init(driver, device)
end

-- discovery: listen for UDP broadcasts on 5555 for a short window
local function discovery(driver, opts, cons)
  log.info("Starting Twinkly discovery...")
  local udp = assert(socket.udp())
  -- bind to all interfaces on port 5555
  local ok, err = udp:setsockname("*", 5555)
  if not ok then
    log.error("Failed to bind UDP socket: " .. tostring(err))
    return
  end
  udp:settimeout(2)

  local start = os.time()
  while os.time() - start < 10 do
    local data, ip, port = udp:receivefrom()
    if data and ip then
      log.info("Discovered Twinkly at " .. ip)
      local metadata = {
        type = "LAN",
        device_network_id = ip,
        label = "Twinkly " .. ip,
        profile = "twinkly-switch",
        manufacturer = "Twinkly",
        model = "LED",
      }
      driver:try_create_device(metadata)
    end
  end
  udp:close()
end

local twinkly_driver = Driver("twinkly", {
  discovery = discovery,
  lifecycle_handlers = { init = device_init, infoChanged = device_info_changed },
  capability_handlers = {
    [caps.switch.ID] = {
      [caps.switch.commands.on.NAME] = switch_on,
      [caps.switch.commands.off.NAME] = switch_off,
    }
  }
})

twinkly_driver:run()
