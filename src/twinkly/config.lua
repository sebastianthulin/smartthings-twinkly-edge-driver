-- 🔧 Twinkly Configuration
-- Centralized configuration for API paths, timeouts, and other settings

local config = {}

------------------------------------------------------------
-- API Configuration
------------------------------------------------------------
config.api = {
  -- Protocol and base settings
  protocol = "http://",
  content_type = "application/json",
  
  -- API endpoints (relative paths)
  endpoints = {
    login = "/xled/v1/login",
    verify = "/xled/v1/verify",
    mode = "/xled/v1/led/mode", 
    brightness = "/xled/v1/led/out/brightness",
    color = "/xled/v1/led/color"
  }
}

------------------------------------------------------------
-- Timing Configuration
------------------------------------------------------------
config.timing = {
  -- Retry delays (in seconds)
  reauth_delay = 0.3,          -- Delay before retrying after auth failure
  token_refresh_delay = 0.4,   -- Delay after token refresh
  poll_failure_delay = 0.3,    -- Delay after polling failure
  
  -- Default intervals
  default_poll_interval = 30,  -- Default device polling interval (seconds)
  min_poll_interval = 1        -- Minimum allowed polling interval (seconds)
}

------------------------------------------------------------
-- Color Configuration  
------------------------------------------------------------
config.color = {
  -- HSV to RGB conversion settings
  saturation_scale = 1.8,      -- Saturation curve factor (higher = more saturation retained)
  gamma = 2.2,                 -- Gamma correction for RGB conversion
  
  -- Color value ranges
  max_rgb_value = 255,         -- Maximum RGB component value
  max_hue_degrees = 360,       -- Maximum hue in degrees
  max_percentage = 100         -- Maximum percentage values (saturation, brightness, etc.)
}

------------------------------------------------------------
-- HTTP Configuration
------------------------------------------------------------
config.http = {
  -- Headers
  auth_header = "X-Auth-Token",
  content_length_header = "Content-Length",
  
  -- Response codes
  success_code = 200,
  unauthorized_code = 401,
  
  -- Error patterns
  invalid_token_pattern = "Invalid Token"
}

------------------------------------------------------------
-- Helper functions to build full URLs
------------------------------------------------------------
function config.build_url(ip, endpoint_key)
  local endpoint = config.api.endpoints[endpoint_key]
  if not endpoint then
    error("Unknown endpoint key: " .. tostring(endpoint_key))
  end
  return config.api.protocol .. ip .. endpoint
end

function config.get_endpoint(endpoint_key)
  return config.api.endpoints[endpoint_key] or error("Unknown endpoint key: " .. tostring(endpoint_key))
end

return config