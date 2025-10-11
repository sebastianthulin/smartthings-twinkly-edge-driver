-- Integration tests for the full device functionality
-- Requires a real Twinkly device or IP configuration
package.path = package.path .. ";../src/?.lua;./?.lua"
_G.IS_LOCAL_TEST = true

-- Mock the log module for integration tests
package.preload["log"] = function()
  return {
    debug = function(...) end,
    info = function(...) print("[INFO]", ...) end,
    warn = function(...) print("[WARN]", ...) end,
    error = function(...) print("[ERROR]", ...) end,
  }
end

local test_utils = require("test-utils")
local twinkly = require("twinkly")
local socket = require("socket")

local test = test_utils.test_framework

-- Get configuration and IP
local config = test_utils.load_config()
local ip

-- Skip integration tests if no IP is configured
local function skip_if_no_ip()
  -- Only use environment variable IP for integration tests
  local env_ip = os.getenv("IP")
  if not env_ip or env_ip == "" then
    print("Skipping integration tests - no IP environment variable configured")
    print("Set IP=your.device.ip.address to run integration tests")
    return true
  end
  ip = env_ip
  return false
end

if skip_if_no_ip() then
  print("Integration tests skipped")
  os.exit(0)
end

print("Running integration tests against device at " .. ip)

-- Test basic connectivity
test.describe("Device responds to get_mode", function()
  local mode = twinkly.get_mode(ip)
  test.assert_not_nil(mode, "Should get a mode from device")
  test.assert_true(mode == "off" or mode == "movie" or mode == "demo", 
                   "Mode should be one of: off, movie, demo")
end)

-- Test mode switching
test.describe("Can switch device on and off", function()
  -- Turn on
  local on_result = twinkly.set_mode(ip, "movie")
  test.assert_not_nil(on_result, "Should succeed turning on")
  
  -- Wait a moment
  socket.sleep(1)
  
  -- Verify it's on
  local mode_on = twinkly.get_mode(ip)
  test.assert_equals(mode_on, "movie", "Device should be in movie mode")
  
  -- Turn off
  local off_result = twinkly.set_mode(ip, "off")
  test.assert_not_nil(off_result, "Should succeed turning off")
  
  -- Wait a moment
  socket.sleep(1)
  
  -- Verify it's off
  local mode_off = twinkly.get_mode(ip)
  test.assert_equals(mode_off, "off", "Device should be off")
end)

-- Test brightness control
test.describe("Can control brightness", function()
  -- First turn on the device
  twinkly.set_mode(ip, "movie")
  socket.sleep(0.5)
  
  -- Test different brightness levels
  for _, level in ipairs(config.test_brightness_levels or {50, 100}) do
    local result = twinkly.set_brightness(ip, level)
    test.assert_not_nil(result, "Should succeed setting brightness to " .. level)
    
    socket.sleep(0.5)
    
    local brightness = twinkly.get_brightness(ip)
    test.assert_not_nil(brightness, "Should get brightness from device")
    -- Allow some tolerance in brightness reading due to device processing
    local BRIGHTNESS_TOLERANCE = 5
    test.assert_true(math.abs(brightness - level) <= BRIGHTNESS_TOLERANCE, 
                     string.format("Brightness should be close to %d, got %d (tolerance: %d)", 
                                   level, brightness, BRIGHTNESS_TOLERANCE))
  end
end)

-- Test color control
test.describe("Can control RGB color", function()
  -- First turn on the device
  twinkly.set_mode(ip, "movie")
  socket.sleep(0.5)
  
  -- Test RGB colors
  for _, color in ipairs(config.test_colors or {{red=255, green=0, blue=0, name="red"}}) do
    local result = twinkly.set_color_rgb(ip, color.red, color.green, color.blue)
    test.assert_not_nil(result, "Should succeed setting color " .. color.name)
    
    socket.sleep(0.5)
    
    local device_color = twinkly.get_color(ip)
    test.assert_not_nil(device_color, "Should get color from device")
    -- Colors might not match exactly due to device processing
    test.assert_not_nil(device_color.red, "Should have red component")
    test.assert_not_nil(device_color.green, "Should have green component") 
    test.assert_not_nil(device_color.blue, "Should have blue component")
  end
end)

-- Test HSV color control
test.describe("Can control HSV color", function()
  -- First turn on the device
  twinkly.set_mode(ip, "movie")
  socket.sleep(0.5)
  
  -- Test HSV colors
  for _, color in ipairs(config.test_hsv_colors or {{hue=0, sat=100, val=100, name="red_hsv"}}) do
    local result = twinkly.set_color_hsv(ip, color.hue, color.sat, color.val)
    test.assert_not_nil(result, "Should succeed setting HSV color " .. color.name)
    
    socket.sleep(0.5)
    
    -- Just verify we can still read the color (conversion back may not be exact)
    local device_color = twinkly.get_color(ip)
    test.assert_not_nil(device_color, "Should get color from device after HSV set")
  end
end)

-- Run tests
print("Running integration tests...")
if not test.run_all() then
  os.exit(1)
end

print("\nAll integration tests passed!")