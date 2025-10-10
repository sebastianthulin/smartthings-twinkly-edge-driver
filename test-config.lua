#!/usr/bin/env lua

-- Simple test to validate configuration module
-- This can be run locally to ensure the config module loads correctly

local function test_config_module()
  print("Testing config module loading...")
  
  -- Mock the require path for local testing
  package.path = package.path .. ";src/?.lua"
  
  local ok, config = pcall(require, "twinkly.config")
  if not ok then
    print("ERROR: Failed to load config module: " .. tostring(config))
    return false
  end
  
  print("✓ Config module loaded successfully")
  
  -- Test API configuration
  if not config.api then
    print("ERROR: config.api not found")
    return false
  end
  
  if config.api.protocol ~= "http://" then
    print("ERROR: Incorrect protocol: " .. tostring(config.api.protocol))
    return false
  end
  
  print("✓ Protocol setting: " .. config.api.protocol)
  
  -- Test endpoints
  if not config.api.endpoints or not config.api.endpoints.login then
    print("ERROR: Endpoints not properly configured")
    return false
  end
  
  print("✓ Login endpoint: " .. config.api.endpoints.login)
  print("✓ Mode endpoint: " .. config.api.endpoints.mode)
  print("✓ Brightness endpoint: " .. config.api.endpoints.brightness)
  print("✓ Color endpoint: " .. config.api.endpoints.color)
  
  -- Test timing configuration
  if not config.timing then
    print("ERROR: config.timing not found")
    return false
  end
  
  print("✓ Default poll interval: " .. config.timing.default_poll_interval)
  print("✓ Reauth delay: " .. config.timing.reauth_delay)
  
  -- Test color configuration
  if not config.color then
    print("ERROR: config.color not found") 
    return false
  end
  
  print("✓ Saturation scale: " .. config.color.saturation_scale)
  print("✓ Gamma: " .. config.color.gamma)
  
  -- Test helper functions
  local test_ip = "192.168.1.100"
  local url = config.build_url(test_ip, "login")
  local expected = "http://192.168.1.100/xled/v1/login"
  
  if url ~= expected then
    print("ERROR: build_url failed. Expected: " .. expected .. ", Got: " .. url)
    return false
  end
  
  print("✓ URL builder works: " .. url)
  
  -- Test get_endpoint
  local endpoint = config.get_endpoint("brightness")
  if endpoint ~= "/xled/v1/led/out/brightness" then
    print("ERROR: get_endpoint failed. Expected: /xled/v1/led/out/brightness, Got: " .. tostring(endpoint))
    return false
  end
  
  print("✓ Endpoint getter works: " .. endpoint)
  
  print("\nAll configuration tests passed! 🎉")
  return true
end

-- Run the test
if not test_config_module() then
  os.exit(1)
end