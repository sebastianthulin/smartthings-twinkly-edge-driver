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
  
  -- API endpoints (relative paths) - based on official REST API documentation
  endpoints = {
    login = "/xled/v1/login",
    verify = "/xled/v1/verify",
    mode = "/xled/v1/led/mode", 
    brightness = "/xled/v1/led/out/brightness",
    color = "/xled/v1/led/color",
    -- Movies management
    movies = "/xled/v1/movies",                    -- Get list of movies
    movies_current = "/xled/v1/led/movies/current", -- Get/set current movie
    -- Effects management  
    effects = "/xled/v1/led/effects",              -- Get available effects
    effects_current = "/xled/v1/led/effects/current", -- Get/set current effect
    -- Movie configuration and upload
    movie_config = "/xled/v1/led/movie/config",    -- Get/set movie config
    movie_full = "/xled/v1/led/movie/full"         -- Upload full movie
  }
}

------------------------------------------------------------
-- Timing Configuration
------------------------------------------------------------
config.timing = {
  -- Retry delays (in seconds)
  reauth_delay = 1.0,          -- Delay before retrying after auth failure (increased)
  token_refresh_delay = 1.0,   -- Delay after token refresh (increased)
  poll_failure_delay = 1.0,    -- Delay after polling failure (increased)
  polling_resume_delay = 3,    -- Delay before resuming polling after device operations (increased)
  
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