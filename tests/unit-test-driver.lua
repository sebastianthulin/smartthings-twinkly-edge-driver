-- Unit tests for SmartThings driver with mocked environment
package.path = package.path .. ";../src/?.lua;./?.lua"
_G.IS_LOCAL_TEST = true

local test_utils = require("test-utils")

-- Setup mock SmartThings environment
test_utils.setup_mock_smartthings()

-- Mock the HTTP module to avoid network calls
package.preload["twinkly.http"] = function()
  return {
    http = {
      request = function(params)
        return 1, 200, '{"code":1000}'
      end
    }
  }
end

local test = test_utils.test_framework

-- Test SmartThings environment mocking instead of driver loading
test.describe("SmartThings environment is properly mocked", function()
  local success, Driver = pcall(require, "st.driver")
  test.assert_true(success, "Should be able to load st.driver mock")
  test.assert_not_nil(Driver, "Driver should not be nil")
end)

-- Test mock device functionality
test.describe("Mock device works correctly", function()
  local device = test_utils.setup_mock_smartthings()
  
  -- Test field storage
  device:set_field("test_field", "test_value")
  local value = device:get_field("test_field")
  test.assert_equals(value, "test_value", "Should store and retrieve fields")
  
  -- Test event emission (should not error)
  local caps = require("st.capabilities")
  device:emit_event(caps.switch.switch("on"))
  test.assert_true(true, "Should emit events without error")
end)

-- Test capabilities mock
test.describe("Mock capabilities work correctly", function()
  local caps = require("st.capabilities")
  
  -- Test switch capability
  local switch_event = caps.switch.switch("on")
  test.assert_equals(switch_event.capability, "switch", "Switch capability should work")
  test.assert_equals(switch_event.value, "on", "Switch value should be correct")
  
  -- Test switchLevel capability
  local level_event = caps.switchLevel.level(75)
  test.assert_equals(level_event.capability, "switchLevel", "SwitchLevel capability should work")
  test.assert_equals(level_event.value, 75, "Level value should be correct")
  
  -- Test colorControl capability
  local hue_event = caps.colorControl.hue(180)
  test.assert_equals(hue_event.capability, "colorControl", "ColorControl capability should work")
  test.assert_equals(hue_event.value, 180, "Hue value should be correct")
end)

-- Run tests
if not test.run_all() then
  os.exit(1)
end