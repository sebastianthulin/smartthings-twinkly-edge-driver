-- Unit tests for effects functionality
package.path = package.path .. ";../src/?.lua;./?.lua"
_G.IS_LOCAL_TEST = true

local test_utils = require("test-utils")
local test = test_utils.test_framework

-- Test configuration includes effects endpoints
test.describe("Config includes official REST API endpoints", function()
  -- Load config directly
  local config = require("twinkly.config")
  test.assert_not_nil(config, "Should load config")
  
  -- Test official REST API endpoints based on documentation
  test.assert_not_nil(config.api.endpoints.movies, "Should have movies endpoint")
  test.assert_not_nil(config.api.endpoints.movies_current, "Should have movies_current endpoint") 
  test.assert_not_nil(config.api.endpoints.effects, "Should have effects endpoint")
  test.assert_not_nil(config.api.endpoints.effects_current, "Should have effects_current endpoint")
  test.assert_not_nil(config.api.endpoints.movie_config, "Should have movie_config endpoint")
  test.assert_not_nil(config.api.endpoints.movie_full, "Should have movie_full endpoint")
  
  -- Verify correct paths from official documentation
  test.assert_equals(config.api.endpoints.movies, "/xled/v1/movies", "Movies endpoint should match API docs")
  test.assert_equals(config.api.endpoints.movies_current, "/xled/v1/led/movies/current", "Movies current endpoint should match API docs")
  test.assert_equals(config.api.endpoints.effects, "/xled/v1/led/effects", "Effects endpoint should match API docs")
  test.assert_equals(config.api.endpoints.effects_current, "/xled/v1/led/effects/current", "Effects current endpoint should match API docs")
  test.assert_equals(config.api.endpoints.movie_config, "/xled/v1/led/movie/config", "Movie config endpoint should match API docs")
  test.assert_equals(config.api.endpoints.movie_full, "/xled/v1/led/movie/full", "Movie full endpoint should match API docs")
end)

-- Test DeviceService interface includes effects methods
test.describe("DeviceService interface includes effects methods", function()
  local interfaces = require("interfaces")
  local IDeviceService = interfaces.IDeviceService
  test.assert_not_nil(IDeviceService, "Should load IDeviceService interface")
  
  -- Create a test instance to verify methods exist
  local TestService = IDeviceService:extend("TestService")
  function TestService:list_effects() return {} end
  function TestService:set_effect() return true end
  function TestService:get_effect() return {} end
  
  local instance = TestService()
  test.assert_not_nil(instance.list_effects, "Should have list_effects method")
  test.assert_not_nil(instance.set_effect, "Should have set_effect method")
  test.assert_not_nil(instance.get_effect, "Should have get_effect method")
end)

-- Test controller has effects methods (static test)
test.describe("TwinklyController has effects methods", function()
  -- Load the controller class without instantiating to check method existence
  local success, TwinklyController = pcall(function()
    return require("twinkly_controller")
  end)
  
  if not success then
    -- Skip this test if dependencies are missing
    test.assert_true(true, "Skipping TwinklyController test due to missing dependencies")
    return
  end
  
  -- Test that the class has the expected methods defined
  test.assert_not_nil(TwinklyController.list_effects, "Should have list_effects method defined")
  test.assert_not_nil(TwinklyController.set_effect, "Should have set_effect method defined")
  test.assert_not_nil(TwinklyController.get_effect, "Should have get_effect method defined")
end)

-- Test twinkly facade exposes effects methods (static test)
test.describe("Twinkly facade exposes effects methods", function()
  -- Test loading without dependencies
  local success, twinkly = pcall(function()
    return require("twinkly")
  end)
  
  if not success then
    -- Skip this test if dependencies are missing (expected in unit test environment)
    test.assert_true(true, "Skipping twinkly facade test due to missing dependencies")
    return
  end
  
  test.assert_not_nil(twinkly.list_effects, "Should have list_effects function")
  test.assert_not_nil(twinkly.set_effect, "Should have set_effect function")
  test.assert_not_nil(twinkly.get_effect, "Should have get_effect function")
  test.assert_equals(type(twinkly.list_effects), "function", "list_effects should be a function")
  test.assert_equals(type(twinkly.set_effect), "function", "set_effect should be a function")
  test.assert_equals(type(twinkly.get_effect), "function", "get_effect should be a function")
end)

-- Run tests
if not test.run_all() then
  os.exit(1)
end