#!/usr/bin/env lua5.4
-- Individual Integration Test Runner
-- Usage: lua run-specific-integration-test.lua <test_name>

package.path = package.path .. ";../src/?.lua;./?.lua;../tests/?.lua"
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

-- Get the test name from command line argument
local test_name = arg and arg[1]
if not test_name then
print("Available tests: get_mode, switch, brightness, rgb_color, hsv_color, list_effects, list_builtin_effects, list_user_effects, activate_effects, random_effect, effects_mode_switching")
  os.exit(1)
end

print("Running integration test: " .. test_name .. " against device at " .. ip)

-- Define all individual test functions
local tests = {}

tests["get_mode"] = function()
  test.describe("Device responds to get_mode", function()
    local mode = twinkly.get_mode(ip)
    test.assert_not_nil(mode, "Should get a mode from device")
    local valid_modes = {off = true, color = true, demo = true, effect = true, movie = true, playlist = true, rt = true}
    test.assert_true(valid_modes[mode], 
                     "Mode should be one of: off, color, demo, effect, movie, playlist, rt - got: " .. tostring(mode))
  end)
end

tests["switch"] = function()
  test.describe("Can switch device on and off", function()
    local on_result = twinkly.set_mode(ip, "movie")
    test.assert_not_nil(on_result, "Should succeed turning on")
    
    socket.sleep(1)
    
    local mode_on = twinkly.get_mode(ip)
    test.assert_equals(mode_on, "movie", "Device should be in movie mode")
    
    local off_result = twinkly.set_mode(ip, "off")
    test.assert_not_nil(off_result, "Should succeed turning off")
    
    socket.sleep(1)
    
    local mode_off = twinkly.get_mode(ip)
    test.assert_equals(mode_off, "off", "Device should be off")
  end)
end

tests["brightness"] = function()
  test.describe("Can control brightness", function()
    twinkly.set_mode(ip, "movie")
    socket.sleep(0.5)
    
    for _, level in ipairs(config.test_brightness_levels or {50, 100}) do
      local result = twinkly.set_brightness(ip, level)
      test.assert_not_nil(result, "Should succeed setting brightness to " .. level)
      
      socket.sleep(0.5)
      
      local brightness = twinkly.get_brightness(ip)
      test.assert_not_nil(brightness, "Should get brightness from device")
    end
  end)
end

tests["rgb_color"] = function()
  test.describe("Can control RGB color", function()
    twinkly.set_mode(ip, "color")
    socket.sleep(0.5)
    
    for _, color in ipairs(config.test_colors or {{red=255, green=0, blue=0, name="red"}}) do
      local result = twinkly.set_color_rgb(ip, color.red, color.green, color.blue)
      test.assert_not_nil(result, "Should succeed setting RGB color " .. (color.name or "test"))
      
      socket.sleep(0.5)
      
      local device_color = twinkly.get_color(ip)
      test.assert_not_nil(device_color, "Should get color from device")
    end
  end)
end

tests["hsv_color"] = function()
  test.describe("Can control HSV color", function()
    twinkly.set_mode(ip, "color")
    socket.sleep(0.5)
    
    for _, color in ipairs(config.test_hsv_colors or {{hue=0, sat=100, val=100, name="red_hsv"}}) do
      local result = twinkly.set_color_hsv(ip, color.hue, color.sat, color.val)
      test.assert_not_nil(result, "Should succeed setting HSV color " .. (color.name or "test"))
      
      socket.sleep(0.5)
      
      local device_color = twinkly.get_color(ip)
      test.assert_not_nil(device_color, "Should get color from device")
    end
  end)
end

tests["list_effects"] = function()
  test.describe("Can list available effects", function()
    local effects = twinkly.list_effects(ip, "all")
    test.assert_not_nil(effects, "Should get effects list from device")
    
    if #effects > 0 then
      print("Note: Found " .. #effects .. " effects on device")
    else
      print("Note: No effects available on device")
    end
  end)
end

tests["list_builtin_effects"] = function()
  test.describe("Can list builtin effects only", function()
    local effects = twinkly.list_effects(ip, "builtin")
    test.assert_not_nil(effects, "Should get builtin effects list from device")
  end)
end

tests["list_user_effects"] = function()
  test.describe("Can list user effects only", function()
    local effects = twinkly.list_effects(ip, "user")
    test.assert_not_nil(effects, "Should get user effects list from device")
  end)
end

tests["activate_effects"] = function()
  test.describe("Can activate effects", function()
    local effects = twinkly.list_effects(ip, "all")
    test.assert_not_nil(effects, "Should get effects list for activation test")
    
    if #effects > 0 then
      local first_effect = effects[1]
      local result = twinkly.set_effect(ip, first_effect.id, first_effect.type)
      test.assert_not_nil(result, "Should succeed activating effect " .. tostring(first_effect.id))
      
      socket.sleep(1)
      
      local mode = twinkly.get_mode(ip)
      local expected_mode = (first_effect.type == "builtin") and "effect" or "movie"
      test.assert_equals(mode, expected_mode, "Device should be in " .. expected_mode .. " mode after " .. first_effect.type .. " effect activation")
    else
      print("Note: Skipping effect activation test - no effects available on device")
    end
  end)
end



tests["random_effect"] = function()
  test.describe("Can set and verify random effect", function()
    local effects = twinkly.list_effects(ip, "all")
    test.assert_not_nil(effects, "Should get effects list")
    
    if #effects > 0 then
      math.randomseed(os.time())
      local random_index = math.random(1, #effects)
      local random_effect = effects[random_index]
      
      print("Testing random effect: " .. tostring(random_effect.name) .. " (type: " .. tostring(random_effect.type) .. ", id: " .. tostring(random_effect.id) .. ")")
      
      local result = twinkly.set_effect(ip, random_effect.id, random_effect.type)
      test.assert_not_nil(result, "Should succeed setting random effect " .. tostring(random_effect.id))
      
      socket.sleep(1)
      
      local mode = twinkly.get_mode(ip)
      local expected_mode = (random_effect.type == "static" or random_effect.type == "builtin") and "effect" or "movie"
      test.assert_equals(mode, expected_mode, "Device should be in " .. expected_mode .. " mode after setting " .. random_effect.type .. " effect")
      

    else
      print("Note: Skipping random effect test - no effects available on device")
    end
  end)
end

tests["effects_mode_switching"] = function()
  test.describe("Effects integration with mode switching", function()
    twinkly.set_mode(ip, "off")
    socket.sleep(0.5)
    
    local mode_off = twinkly.get_mode(ip)
    test.assert_equals(mode_off, "off", "Device should start off")
    
    local effects = twinkly.list_effects(ip, "all")
    test.assert_not_nil(effects, "Should get effects list")
    
    if #effects > 0 then
      local test_effect = effects[1]
      local result = twinkly.set_effect(ip, test_effect.id, test_effect.type)
      test.assert_not_nil(result, "Should succeed activating effect")
      
      socket.sleep(1)
      
      local mode_on = twinkly.get_mode(ip)
      local expected_mode = (test_effect.type == "builtin") and "effect" or "movie"
      test.assert_equals(mode_on, expected_mode, "Device should be in " .. expected_mode .. " mode after " .. test_effect.type .. " effect")
      
      twinkly.set_mode(ip, "off")
      socket.sleep(0.5)
      
      local mode_final = twinkly.get_mode(ip)
      test.assert_equals(mode_final, "off", "Device should be off after turning off")
    else
      print("Note: Skipping effects integration test - no effects available on device")
    end
  end)
end

-- Execute the specified test
if tests[test_name] then
  tests[test_name]()
  
  -- Run the test framework
  print("Running test: " .. test_name)
  if not test.run_all() then
    os.exit(1)
  end
  
  print("✓ Integration test '" .. test_name .. "' passed!")
else
  print("Error: Unknown test name '" .. test_name .. "'")
  print("Available tests: get_mode, switch, brightness, rgb_color, hsv_color, list_effects, list_builtin_effects, list_user_effects, activate_effects, random_effect, effects_mode_switching")
  os.exit(1)
end