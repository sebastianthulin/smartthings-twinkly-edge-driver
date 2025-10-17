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
  -- Valid modes from official Twinkly REST API documentation
  local valid_modes = {off = true, color = true, demo = true, effect = true, movie = true, playlist = true, rt = true}
  test.assert_true(valid_modes[mode], 
                   "Mode should be one of: off, color, demo, effect, movie, playlist, rt - got: " .. tostring(mode))
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

-- Test effects functionality
test.describe("Can list available effects", function()
  local effects = twinkly.list_effects(ip, "all")
  test.assert_not_nil(effects, "Should get effects list")
  test.assert_true(type(effects) == "table", "Effects should be a table")
  
  print("!!!!!!!!Effects found: " .. #effects)
  for i, effect in ipairs(effects) do
    print("  Effect " .. i .. ": id=" .. tostring(effect.id) .. ", name=" .. tostring(effect.name) .. ", type=" .. tostring(effect.type))
    if effect.unique_id then
      print("    unique_id=" .. tostring(effect.unique_id))
    end
  end
  
  -- Some devices may not have any pre-installed effects, which is acceptable
  if #effects > 0 then
    -- Check effect structure if effects are available
    local first_effect = effects[1]
    test.assert_not_nil(first_effect.id, "Effect should have an ID")
    test.assert_not_nil(first_effect.name, "Effect should have a name")
    print("Note: Found " .. #effects .. " effects on device")
  else
    print("Note: No effects found on device (acceptable for some firmware versions)")
  end
end)

test.describe("Can list builtin effects only", function()
  local builtin_effects = twinkly.list_effects(ip, "builtin")
  test.assert_not_nil(builtin_effects, "Should get builtin effects list")
  test.assert_true(type(builtin_effects) == "table", "Builtin effects should be a table")
end)

test.describe("Can list user effects only", function()
  local user_effects = twinkly.list_effects(ip, "user")
  test.assert_not_nil(user_effects, "Should get user effects list")
  test.assert_true(type(user_effects) == "table", "User effects should be a table")
end)

test.describe("Can activate effects", function()
  -- First get available effects
  local effects = twinkly.list_effects(ip, "all")
  test.assert_not_nil(effects, "Should get effects list for activation test")
  
  if #effects > 0 then
    -- Try to activate the first effect
    local first_effect = effects[1]
    local result = twinkly.set_effect(ip, first_effect.id, first_effect.type)
    test.assert_not_nil(result, "Should succeed activating effect " .. tostring(first_effect.id))
    
    socket.sleep(1)  -- Give effect time to activate
    
    -- Verify the device is in the correct mode based on effect type
    local mode = twinkly.get_mode(ip)
    local expected_mode = (first_effect.type == "builtin") and "effect" or "movie"
    test.assert_equals(mode, expected_mode, "Device should be in " .. expected_mode .. " mode after " .. first_effect.type .. " effect activation")
  else
    print("Note: Skipping effect activation test - no effects available on device")
  end
end)

test.describe("Can get current effect information", function()
  -- First activate an effect
  local effects = twinkly.list_effects(ip, "all")
  test.assert_not_nil(effects, "Should get effects list")
  
  if #effects > 0 then
    local test_effect = effects[1]
    twinkly.set_effect(ip, test_effect.id, test_effect.type)
    socket.sleep(1)
    
    -- Try to get current effect
    local current_effect = twinkly.get_effect(ip)
    -- Note: This may return nil on some firmware versions, so we test gracefully
    if current_effect then
      test.assert_not_nil(current_effect.id, "Current effect should have an ID")
      test.assert_not_nil(current_effect.name, "Current effect should have a name")
    else
      -- Some devices may not support getting current effect
      print("Note: Device does not support getting current effect (acceptable)")
    end
  else
    print("Note: Skipping current effect test - no effects available on device")
  end
end)

test.describe("Can set and verify random effect", function()
  -- Get all available effects
  local effects = twinkly.list_effects(ip, "all")
  test.assert_not_nil(effects, "Should get effects list")
  
   -- Print debug info, full object random_effect
  print("!!!!!!!!EFX List: ")
  for k, v in pairs(effects) do
    print("  " .. tostring(k) .. ": " .. tostring(v))
  end

  if #effects > 0 then
    -- Choose a random effect from the list
    math.randomseed(os.time())
    local random_index = math.random(1, #effects)
    local random_effect = effects[random_index]
    
    print("Testing random effect: " .. tostring(random_effect.name) .. " (type: " .. tostring(random_effect.type) .. ", id: " .. tostring(random_effect.id) .. ")")
    
    -- Apply the random effect
    local result = twinkly.set_effect(ip, random_effect.id, random_effect.type)
    test.assert_not_nil(result, "Should succeed setting random effect " .. tostring(random_effect.id))
    
    socket.sleep(1)  -- Give effect time to activate
    
    -- Verify the device is in the correct mode
    local mode = twinkly.get_mode(ip)
    local expected_mode = (random_effect.type == "builtin") and "effect" or "movie"
    test.assert_equals(mode, expected_mode, "Device should be in " .. expected_mode .. " mode after setting " .. random_effect.type .. " effect")
    
    -- Print debug info, full object random_effect
    print("!!!!!!!!Random effect details: ")
    for k, v in pairs(random_effect) do
      print("  " .. tostring(k) .. ": " .. tostring(v))
    end

    -- Print debug info, current mode
    print("!!!!!!!!Current device mode: " .. tostring(mode))

    -- Try to verify the current effect (if supported)
    local current_effect = twinkly.get_effect(ip)
    if current_effect then
      print("!!!!!!!!Current effect details: ")
      for k, v in pairs(current_effect) do
        print("  " .. tostring(k) .. ": " .. tostring(v))
      end
      
      test.assert_equals(current_effect.id, random_effect.id, "Current effect ID should match the set effect ID")
      print("✓ Verified current effect ID matches set effect: " .. tostring(current_effect.id))
    else
      print("Note: Device does not support getting current effect - cannot verify effect ID match")
    end
  else
    print("Note: Skipping random effect test - no effects available on device")
  end
end)

test.describe("Effects integration with mode switching", function()
  -- Test that effects properly manage device mode
  
  -- Start with device off
  twinkly.set_mode(ip, "off")
  socket.sleep(0.5)
  
  local mode_off = twinkly.get_mode(ip)
  test.assert_equals(mode_off, "off", "Device should start off")
  
  -- Activate an effect (should turn device on)
  local effects = twinkly.list_effects(ip, "all")
  test.assert_not_nil(effects, "Should get effects list")
  
  if #effects > 0 then
    local test_effect = effects[1]
    local result = twinkly.set_effect(ip, test_effect.id, test_effect.type)
    test.assert_not_nil(result, "Should succeed activating effect")
    
    socket.sleep(1)
    
    -- Verify device is now on in the correct mode based on effect type
    local mode_on = twinkly.get_mode(ip)
    local expected_mode = (test_effect.type == "builtin") and "effect" or "movie"
    test.assert_equals(mode_on, expected_mode, "Device should be in " .. expected_mode .. " mode after " .. test_effect.type .. " effect")
    
    -- Turn off and verify
    twinkly.set_mode(ip, "off")
    socket.sleep(0.5)
    
    local mode_final = twinkly.get_mode(ip)
    test.assert_equals(mode_final, "off", "Device should be off after turning off")
  else
    print("Note: Skipping effects integration test - no effects available on device")
  end
end)

-- Run tests
print("Running integration tests...")
if not test.run_all() then
  os.exit(1)
end

print("\nAll integration tests passed!")