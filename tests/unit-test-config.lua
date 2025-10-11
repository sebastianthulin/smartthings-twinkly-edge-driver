-- Unit tests for configuration and environment handling
package.path = package.path .. ";../src/?.lua;./?.lua"
_G.IS_LOCAL_TEST = true

local test_utils = require("test-utils")
local test = test_utils.test_framework

-- Test configuration loading
test.describe("Config loads default values from example", function()
  local config = test_utils.load_config()
  test.assert_not_nil(config, "Should load config")
  test.assert_not_nil(config.default_ip, "Should have default_ip")
end)

-- Test environment variable override
test.describe("Environment variables override config", function()
  -- Set a test IP
  os.execute("export TEST_IP=192.168.99.99")
  
  -- Mock environment variable access
  local original_getenv = os.getenv
  os.getenv = function(var)
    if var == "IP" then
      return "192.168.99.99"
    end
    return original_getenv(var)
  end
  
  local config = test_utils.load_config()
  test.assert_equals(config.default_ip, "192.168.99.99", "Should use environment IP")
  
  -- Restore original function
  os.getenv = original_getenv
end)

-- Test get_test_ip function
test.describe("get_test_ip returns valid IP", function()
  local original_getenv = os.getenv
  os.getenv = function(var)
    if var == "IP" then
      return "192.168.1.100"
    end
    return original_getenv(var)
  end
  
  local ip = test_utils.get_test_ip()
  test.assert_equals(ip, "192.168.1.100", "Should return environment IP")
  
  os.getenv = original_getenv
end)

-- Run tests
if not test.run_all() then
  os.exit(1)
end