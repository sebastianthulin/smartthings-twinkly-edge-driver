-- Test utilities and framework
-- Provides a simple test framework and common utilities for testing

local test_utils = {}

-- Test configuration loader
function test_utils.load_config()
  local config = {}
  
  -- Try to load test-config.lua first
  local ok, loaded_config = pcall(require, "test-config")
  if ok and loaded_config then
    config = loaded_config
  else
    -- Fall back to example config - need to navigate to parent directory
    package.path = package.path .. ";../?.lua"
    local example_ok, example_config = pcall(require, "test-config.example")
    if example_ok and example_config then
      config = example_config
    else
      -- Provide basic defaults if no config is found
      config = {
        default_ip = "192.168.1.45",
        timeout = 10,
        test_brightness_levels = {50, 100},
        test_colors = {{red=255, green=0, blue=0, name="red"}},
        test_hsv_colors = {{hue=0, sat=100, val=100, name="red_hsv"}}
      }
    end
  end
  
  -- Override with environment variables
  local env_ip = os.getenv("IP")
  if env_ip and env_ip ~= "" then
    config.default_ip = env_ip
  end
  
  return config
end

-- Get IP address for testing
function test_utils.get_test_ip()
  local config = test_utils.load_config()
  local ip = os.getenv("IP") or config.default_ip
  
  if not ip or ip == "" then
    error("No IP address configured. Set IP environment variable or create test-config.lua")
  end
  
  return ip
end

-- Simple test framework
local test_framework = {
  tests = {},
  results = {passed = 0, failed = 0, errors = {}},
}

function test_framework.describe(description, test_func)
  table.insert(test_framework.tests, {desc = description, func = test_func})
end

function test_framework.assert_equals(actual, expected, message)
  if actual ~= expected then
    error(string.format("Assertion failed: %s\nExpected: %s\nActual: %s", 
          message or "values not equal", tostring(expected), tostring(actual)))
  end
end

function test_framework.assert_true(value, message)
  if not value then
    error(message or "Expected true, got false")
  end
end

function test_framework.assert_not_nil(value, message)
  if value == nil then
    error(message or "Expected non-nil value")
  end
end

function test_framework.run_all()
  print("Running " .. #test_framework.tests .. " tests...")
  print("=" .. string.rep("=", 50))
  
  for i, test in ipairs(test_framework.tests) do
    local status, err = pcall(test.func)
    if status then
      print(string.format("✓ %d. %s", i, test.desc))
      test_framework.results.passed = test_framework.results.passed + 1
    else
      print(string.format("✗ %d. %s", i, test.desc))
      print("  Error:", err)
      test_framework.results.failed = test_framework.results.failed + 1
      table.insert(test_framework.results.errors, {test = test.desc, error = err})
    end
  end
  
  print("=" .. string.rep("=", 50))
  local total = test_framework.results.passed + test_framework.results.failed
  print(string.format("Results: %d passed, %d failed out of %d total", 
        test_framework.results.passed, test_framework.results.failed, total))
  
  if test_framework.results.failed > 0 then
    print("\nFailure details:")
    for i, err in ipairs(test_framework.results.errors) do
      print(string.format("%d. %s: %s", i, err.test, err.error))
    end
    return false
  end
  
  return true
end

test_utils.test_framework = test_framework

-- Mock SmartThings environment for unit testing
function test_utils.setup_mock_smartthings()
  -- Mock the st.driver module
  package.preload["st.driver"] = function()
    return {
      Driver = function(name, config)
        return {
          name = name,
          config = config,
          call_with_delay = function(self, delay, callback)
            -- Mock timer - just return a dummy timer ID
            return "mock_timer_" .. tostring(math.random(1000))
          end
        }
      end
    }
  end
  
  -- Mock st.capabilities
  package.preload["st.capabilities"] = function()
    return {
      switch = {
        ID = "switch",
        commands = {
          on = {NAME = "on"},
          off = {NAME = "off"}
        },
        switch = function(state) 
          return {capability = "switch", attribute = "switch", value = state}
        end
      },
      switchLevel = {
        ID = "switchLevel", 
        commands = {
          setLevel = {NAME = "setLevel"}
        },
        level = function(level)
          return {capability = "switchLevel", attribute = "level", value = level}
        end
      },
      colorControl = {
        ID = "colorControl",
        commands = {
          setColor = {NAME = "setColor"},
          setHue = {NAME = "setHue"},
          setSaturation = {NAME = "setSaturation"}
        },
        hue = function(hue)
          return {capability = "colorControl", attribute = "hue", value = hue}
        end,
        saturation = function(sat)
          return {capability = "colorControl", attribute = "saturation", value = sat}
        end
      }
    }
  end
  
  -- Mock device object
  local mock_device = {
    id = "mock_device_id",
    label = "Mock Twinkly Device",
    preferences = {},
    fields = {},
    
    get_field = function(self, field)
      return self.fields[field]
    end,
    
    set_field = function(self, field, value, options)
      self.fields[field] = value
    end,
    
    emit_event = function(self, event)
      print("Mock event:", event.capability, event.attribute, "=", event.value)
    end
  }
  
  return mock_device
end

-- Utility to wait with timeout
function test_utils.wait_with_timeout(condition, timeout, interval)
  timeout = timeout or 10
  interval = interval or 0.1
  local start_time = os.time()
  
  while os.time() - start_time < timeout do
    if condition() then
      return true
    end
    -- Simple sleep implementation
    os.execute("sleep " .. interval)
  end
  
  return false
end

return test_utils