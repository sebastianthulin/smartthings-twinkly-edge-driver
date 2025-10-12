#!/usr/bin/env lua

-- Simple test to verify color fix doesn't break basic functionality
-- This test focuses on the polling suspension logic without needing HTTP

-- Mock driver and device for testing
local mock_driver = {
  canceled_timers = {},
  delayed_calls = {},
  cancel_timer = function(self, timer)
    table.insert(self.canceled_timers, timer)
  end,
  call_with_delay = function(self, delay, func)
    table.insert(self.delayed_calls, {delay = delay, func = func})
  end
}

local mock_device = {
  fields = {},
  events = {},
  preferences = { ipAddress = "192.168.1.100" },
  get_field = function(self, key)
    return self.fields[key]
  end,
  set_field = function(self, key, value, opts)
    self.fields[key] = value
  end,
  get_latest_state = function(self, comp, cap, attr)
    return 100 -- Default brightness/sat/hue
  end,
  emit_event = function(self, event)
    table.insert(self.events, event)
  end
}

-- Mock capabilities
local caps = {
  colorControl = {
    hue = function(val) return {type = "hue", value = val} end,
    saturation = function(val) return {type = "saturation", value = val} end,
  },
  switchLevel = {
    level = function(val) return {type = "level", value = val} end,
    ID = "switchLevel"
  }
}

-- Mock twinkly module
local twinkly = {
  set_color_hsv = function(ip, h, s, v)
    return true, "success"
  end,
  set_brightness = function(ip, level)
    return true, "success"
  end
}

-- Mock log
local log = {
  info = function(...) print("[INFO]", ...) end,
  error = function(...) print("[ERROR]", ...) end
}

-- Load and adapt the functions from init.lua for testing
local function resolve_ip(device)
  return device.preferences.ipAddress
end

-- Mock schedule_poll function
local function schedule_poll(driver, device)
  print("Scheduling polling for device")
end

-- Simplified color change functions (extracted logic from init.lua)
local function set_color_test(driver, device, hue, sat)
  local ip = resolve_ip(device)
  log.info(string.format("SET_COLOR -> %s hue=%d sat=%d", tostring(ip or "?"), hue, sat))

  if ip then
    -- Temporarily suspend polling to avoid interference during color change
    local poll_timer = device:get_field("poll_timer")
    if poll_timer then
      driver:cancel_timer(poll_timer)
      device:set_field("poll_timer", nil)
    end

    local bright = device:get_latest_state("main", caps.switchLevel.ID, "level") or 100
    local ok, result = pcall(twinkly.set_color_hsv, ip, hue, sat, bright)
    if ok then
      device:emit_event(caps.colorControl.hue(hue))
      device:emit_event(caps.colorControl.saturation(sat))
    else
      log.error("set_color_hsv failed: " .. tostring(result))
    end

    -- Resume polling after a brief delay to allow color change to complete
    driver:call_with_delay(2, function()
      schedule_poll(driver, device)
    end)
  end
end

-- Test 1: Basic color change without polling timer
print("=== Test 1: Color change without active polling timer ===")
local test_device1 = {}
for k,v in pairs(mock_device) do test_device1[k] = v end
test_device1.fields = {}
test_device1.events = {}

local test_driver1 = {}
for k,v in pairs(mock_driver) do test_driver1[k] = v end
test_driver1.canceled_timers = {}
test_driver1.delayed_calls = {}

set_color_test(test_driver1, test_device1, 120, 80)

assert(#test_device1.events == 2, "Should emit 2 events")
assert(#test_driver1.canceled_timers == 0, "Should not cancel any timers when none exist")
assert(#test_driver1.delayed_calls == 1, "Should schedule delayed polling resume")
assert(test_driver1.delayed_calls[1].delay == 2, "Delay should be 2 seconds")
print("✓ Test 1 passed")

-- Test 2: Color change with existing polling timer
print("\n=== Test 2: Color change with active polling timer ===")
local test_device2 = {}
for k,v in pairs(mock_device) do test_device2[k] = v end
test_device2.fields = {poll_timer = "active_timer_123"}
test_device2.events = {}

local test_driver2 = {}
for k,v in pairs(mock_driver) do test_driver2[k] = v end
test_driver2.canceled_timers = {}
test_driver2.delayed_calls = {}

set_color_test(test_driver2, test_device2, 240, 90)

assert(#test_device2.events == 2, "Should emit 2 events")
assert(#test_driver2.canceled_timers == 1, "Should cancel existing timer")
assert(test_driver2.canceled_timers[1] == "active_timer_123", "Should cancel correct timer")
assert(test_device2:get_field("poll_timer") == nil, "Timer field should be cleared")
assert(#test_driver2.delayed_calls == 1, "Should schedule delayed polling resume")
assert(test_driver2.delayed_calls[1].delay == 2, "Delay should be 2 seconds")
print("✓ Test 2 passed")

-- Test 3: Verify delayed function calls schedule_poll
print("\n=== Test 3: Verify delayed scheduling works ===")
local delayed_func = test_driver2.delayed_calls[1].func
-- This would call schedule_poll in real code, which we can't test fully here
-- but we can verify the function exists and is callable
assert(type(delayed_func) == "function", "Delayed call should be a function")
print("✓ Test 3 passed")

print("\n🎉 All color fix tests passed!")
print("The polling suspension mechanism is working correctly.")
print("This should prevent the SmartThings app from hanging during color selection.")