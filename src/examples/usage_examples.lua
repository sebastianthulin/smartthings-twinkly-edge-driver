-- Usage Examples for the New SOLID Architecture
-- This file demonstrates the power and flexibility of the new design
--
-- NOTE: Run this file from the project root directory:
-- lua5.4 src/examples/usage_examples.lua

-- Set up module path for this example (run from project root)
local current_dir = debug.getinfo(1).source:match("@?(.*/)")
if current_dir then
  package.path = package.path .. ';' .. current_dir .. '../?.lua'
else
  -- Fallback: assume running from project root
  package.path = package.path .. ';src/?.lua'
end

local ServiceFactory = require "service_factory"
local class = require "vendor.30log"

print("=== Twinkly Driver Architecture Examples ===")
print()

-- Example 1: Basic usage (backward compatible)
print("1. Basic Usage (Backward Compatible):")
local twinkly = require "twinkly"
print("   Available functions:", table.concat({"set_mode", "get_mode", "set_brightness", "set_color_rgb"}, ", "))
print("   New functions:", "health_check")
print()

-- Example 2: Direct service container usage
print("2. Advanced Usage with Service Container:")
local container = ServiceFactory.create_container()
local logger = container:resolve("logger")
local color_converter = container:resolve("color_converter")

logger:info("Logger service resolved successfully")
local r, g, b = color_converter:hsv_to_rgb(120, 0.8, 1.0)
print(string.format("   HSV(120°, 80%%, 100%%) -> RGB(%d, %d, %d)", r, g, b))
print()

-- Example 3: Creating custom services using the framework
print("3. Extending with Custom Services:")

-- Define a new interface for device monitoring
local IDeviceMonitor = class("IDeviceMonitor", {
  start_monitoring = function(self, ip, interval)
    error("IDeviceMonitor:start_monitoring() must be implemented")
  end,
  
  stop_monitoring = function(self, ip)
    error("IDeviceMonitor:stop_monitoring() must be implemented")
  end,
  
  get_status = function(self, ip)
    error("IDeviceMonitor:get_status() must be implemented")
  end
})

-- Implement the monitoring service
local DeviceMonitor = IDeviceMonitor:extend("DeviceMonitor")

function DeviceMonitor:init(twinkly_controller, logger)
  self._controller = twinkly_controller
  self._logger = logger
  self._monitoring = {}
end

function DeviceMonitor:start_monitoring(ip, interval)
  if self._monitoring[ip] then
    return false, "Already monitoring " .. ip
  end
  
  self._monitoring[ip] = {
    interval = interval or 30,
    started = os.time(),
    last_check = nil
  }
  
  self._logger:info("Started monitoring " .. ip .. " every " .. (interval or 30) .. " seconds")
  return true
end

function DeviceMonitor:stop_monitoring(ip)
  if not self._monitoring[ip] then
    return false, "Not monitoring " .. ip
  end
  
  self._monitoring[ip] = nil
  self._logger:info("Stopped monitoring " .. ip)
  return true
end

function DeviceMonitor:get_status(ip)
  local monitor_info = self._monitoring[ip]
  if not monitor_info then
    return nil, "Not monitoring this IP"
  end
  
  -- Safely call health_check with error handling
  local health = nil
  local health_error = nil
  local success, result = pcall(function() 
    return self._controller:health_check(ip) 
  end)
  
  if success then
    health = result
  else
    health_error = result
    self._logger:warn("Health check failed for " .. ip .. ": " .. tostring(result))
  end
  
  monitor_info.last_check = os.time()
  
  return {
    ip = ip,
    monitoring_since = monitor_info.started,
    last_check = monitor_info.last_check,
    interval = monitor_info.interval,
    device_health = health,
    health_error = health_error
  }
end

-- Register the new service in container
container:register("device_monitor", DeviceMonitor:new(
  container:resolve("twinkly_controller"),
  container:resolve("logger")
))

local monitor = container:resolve("device_monitor")
monitor:start_monitoring("192.168.1.100", 60)
print("   Custom DeviceMonitor service created and registered")
print("   Started monitoring 192.168.1.100 every 60 seconds")
print()

-- Example 4: Dependency injection for testing
print("4. Testing with Dependency Injection:")

-- Create a mock HTTP client for testing
local MockHttpClient = class("MockHttpClient")

function MockHttpClient:init()
  self.requests = {}
end

function MockHttpClient:request(params)
  table.insert(self.requests, {
    url = params.url,
    method = params.method or "GET",
    body = params.body,
    timestamp = os.time()
  })
  
  -- Simulate successful response
  return {
    success = true,
    status_code = 200,
    body = '{"mode": "movie", "value": 80}',
    headers = {},
    status_line = "HTTP/1.1 200 OK"
  }
end

function MockHttpClient:get_request_history()
  return self.requests
end

-- Create test container with mock
local test_container = require("services.container"):new()
test_container:register("logger", require("services.logger"):new())
test_container:register("http_client", MockHttpClient:new())

print("   Mock HTTP client created for testing")
print("   This enables unit testing without real network calls")
print()

-- Example 5: Service extension through inheritance
print("5. Service Extension through Inheritance:")

-- Create an enhanced device service using proper factory pattern
local base_device_service = container:resolve("device_service")
local DeviceServiceClass = require("services.device_service")
local EnhancedDeviceService = DeviceServiceClass:extend("EnhancedDeviceService")

function EnhancedDeviceService:set_color_with_transition(ip, red, green, blue, duration)
  self._logger:info(string.format("Setting color RGB(%d,%d,%d) with %ds transition for %s", 
    red, green, blue, duration or 1, ip))
  
  -- In a real implementation, this could animate the color change
  return self:set_color_rgb(ip, red, green, blue)
end

function EnhancedDeviceService:get_device_info(ip)
  local mode = self:get_mode(ip)
  local brightness = self:get_brightness(ip)
  local color = self:get_color(ip)
  
  return {
    ip = ip,
    mode = mode,
    brightness = brightness,
    color = color,
    timestamp = os.time()
  }
end

print("   Enhanced device service with new methods created")
print("   - set_color_with_transition()")
print("   - get_device_info()")
print()

print("=== Architecture Benefits Demonstrated ===")
print("✓ Backward compatibility maintained")
print("✓ Easy service extension and customization")
print("✓ Dependency injection enables testing")  
print("✓ Clear separation of concerns")
print("✓ Interface-based design allows swapping implementations")
print("✓ Service container manages object lifecycles")
print()
print("The SOLID architecture makes the codebase more maintainable,")
print("testable, and extensible while preserving all existing functionality!")