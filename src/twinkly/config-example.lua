-- 🔧 Example: Alternative Configuration for Different Firmware
-- This demonstrates how to create configuration variants for different Twinkly firmware versions

local base_config = require "twinkly.config"

-- Example configuration for newer firmware (hypothetical v2 API)
local config_v2 = {}

-- Copy base configuration
for k, v in pairs(base_config) do
  config_v2[k] = v
end

-- Override specific settings for v2 firmware
config_v2.api = {
  protocol = "https://",  -- Maybe newer firmware uses HTTPS
  content_type = "application/json",
  
  -- Updated API endpoints for v2
  endpoints = {
    login = "/xled/v2/auth/login",           -- Updated path
    verify = "/xled/v2/auth/verify",         -- Updated path
    mode = "/xled/v2/device/mode",           -- Updated path  
    brightness = "/xled/v2/device/brightness", -- Updated path
    color = "/xled/v2/device/color"          -- Updated path
  }
}

-- Maybe v2 has different timing requirements
config_v2.timing = {
  reauth_delay = 0.5,          -- Slower reauth for newer firmware
  token_refresh_delay = 0.6,   -- Longer token refresh delay
  poll_failure_delay = 0.5,    
  
  default_poll_interval = 60,  -- Less frequent polling for efficiency
  min_poll_interval = 5        
}

-- Example configuration for legacy firmware (hypothetical v0 API)  
local config_legacy = {}

-- Copy base configuration
for k, v in pairs(base_config) do
  config_legacy[k] = v
end

-- Override for legacy firmware
config_legacy.api = {
  protocol = "http://",
  content_type = "application/json",
  
  -- Legacy API paths
  endpoints = {
    login = "/xled/v1/login",
    verify = "/xled/v1/verify", 
    mode = "/xled/v1/led/mode",
    brightness = "/xled/v1/led/brightness",  -- Different from current
    color = "/xled/v1/led/rgb"               -- Different from current
  }
}

-- Legacy might need faster retries
config_legacy.timing = {
  reauth_delay = 0.1,
  token_refresh_delay = 0.2,  
  poll_failure_delay = 0.1,
  
  default_poll_interval = 15,  -- More frequent polling for stability
  min_poll_interval = 1
}

--[[
Usage example:

-- In your main module, you could detect firmware version and select config:

local config
local firmware_version = detect_firmware_version(ip)

if firmware_version == "v2" then
  config = require "twinkly.config-v2"
elseif firmware_version == "legacy" then  
  config = require "twinkly.config-legacy"
else
  config = require "twinkly.config"  -- default
end

-- Then use config normally:
local url = config.build_url(ip, "login")
socket.sleep(config.timing.reauth_delay)
--]]

-- For demonstration, return the v2 config
return config_v2