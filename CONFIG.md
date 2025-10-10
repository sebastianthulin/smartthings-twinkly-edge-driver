# Twinkly Configuration System

This document explains the centralized configuration system implemented for the Twinkly Edge Driver.

## Overview

The configuration system centralizes all static paths, timeouts, and other configuration values in a single module (`src/twinkly/config.lua`). This makes it easy to adapt the driver for different Twinkly firmware versions by simply injecting a different configuration.

## Benefits

- **Centralized Management**: All configuration values in one place
- **Easy Adaptation**: Switch configurations for different firmware versions
- **Maintainability**: No more hunting for hardcoded values across multiple files
- **Consistency**: Guaranteed consistent values across all modules
- **Future-Proofing**: Easy to extend with new configuration options

## Configuration Structure

### API Configuration (`config.api`)

```lua
config.api = {
  protocol = "http://",                    -- HTTP protocol scheme
  content_type = "application/json",       -- Default content type
  
  endpoints = {
    login = "/xled/v1/login",              -- Authentication endpoint
    verify = "/xled/v1/verify",            -- Token verification endpoint
    mode = "/xled/v1/led/mode",            -- Device mode endpoint
    brightness = "/xled/v1/led/out/brightness", -- Brightness control endpoint
    color = "/xled/v1/led/color"           -- Color control endpoint
  }
}
```

### Timing Configuration (`config.timing`)

```lua
config.timing = {
  reauth_delay = 0.3,          -- Delay before retrying after auth failure (seconds)
  token_refresh_delay = 0.4,   -- Delay after token refresh (seconds)
  poll_failure_delay = 0.3,    -- Delay after polling failure (seconds)
  
  default_poll_interval = 30,  -- Default device polling interval (seconds)
  min_poll_interval = 1        -- Minimum allowed polling interval (seconds)
}
```

### Color Configuration (`config.color`)

```lua
config.color = {
  saturation_scale = 1.8,      -- Saturation curve factor for HSV conversion
  gamma = 2.2,                 -- Gamma correction for RGB conversion
  
  max_rgb_value = 255,         -- Maximum RGB component value
  max_hue_degrees = 360,       -- Maximum hue in degrees
  max_percentage = 100         -- Maximum percentage values
}
```

### HTTP Configuration (`config.http`)

```lua
config.http = {
  auth_header = "X-Auth-Token",            -- Authentication header name
  content_length_header = "Content-Length", -- Content length header name
  
  success_code = 200,          -- HTTP success status code
  unauthorized_code = 401,     -- HTTP unauthorized status code
  
  invalid_token_pattern = "Invalid Token"  -- Pattern to detect invalid tokens
}
```

## Helper Functions

### `config.build_url(ip, endpoint_key)`

Builds a complete URL for the given IP and endpoint.

```lua
local url = config.build_url("192.168.1.100", "login")
-- Returns: "http://192.168.1.100/xled/v1/login"
```

### `config.get_endpoint(endpoint_key)`

Gets an endpoint path by its key.

```lua
local path = config.get_endpoint("brightness")
-- Returns: "/xled/v1/led/out/brightness"
```

## Usage Examples

### In Module Code

```lua
local config = require "twinkly.config"

-- Use configured endpoints
local url = config.build_url(ip, "mode")

-- Use configured timing
socket.sleep(config.timing.reauth_delay)

-- Use configured constants
local max_brightness = config.color.max_rgb_value
```

### Error Handling

```lua
-- Use configured error codes and patterns
if code == config.http.unauthorized_code or 
   (resp_body and resp_body:match(config.http.invalid_token_pattern)) then
  -- Handle authentication error
end
```

## Adapting for Different Firmware

To support different Twinkly firmware versions, create alternative configuration files:

### Example: config-v2.lua

```lua
local base_config = require "twinkly.config"
local config_v2 = {}

-- Copy base configuration
for k, v in pairs(base_config) do
  config_v2[k] = v
end

-- Override for v2 firmware
config_v2.api.endpoints = {
  login = "/xled/v2/auth/login",
  verify = "/xled/v2/auth/verify", 
  mode = "/xled/v2/device/mode",
  brightness = "/xled/v2/device/brightness",
  color = "/xled/v2/device/color"
}

return config_v2
```

### Dynamic Configuration Selection

```lua
-- Detect firmware version and select appropriate config
local config
local firmware_version = detect_firmware_version(ip)

if firmware_version == "v2" then
  config = require "twinkly.config-v2"
elseif firmware_version == "legacy" then
  config = require "twinkly.config-legacy"  
else
  config = require "twinkly.config"  -- default
end
```

## Migrated Values

The following previously hardcoded values are now centrally configured:

### URLs and Paths
- All `/xled/v1/*` endpoint paths
- HTTP protocol scheme (`http://`)

### Timing Values
- Sleep delays: `0.3s`, `0.4s`
- Default polling interval: `30 seconds`
- Minimum polling interval: `1 second`

### Constants
- Saturation scale: `1.8`
- Gamma correction: `2.2` 
- Maximum RGB value: `255`
- HTTP status codes: `200`, `401`

### Headers
- Authentication header: `X-Auth-Token`
- Content-Type: `application/json`
- Content-Length header

## Testing

Use the provided test file to validate configuration:

```bash
lua test-config.lua
```

This will verify:
- Configuration module loads correctly
- All required sections are present
- Helper functions work as expected
- Values are properly configured

## Best Practices

1. **Import Once**: Import the config module at the top of each file that needs it
2. **Use Helpers**: Prefer `config.build_url()` and `config.get_endpoint()` over manual string concatenation  
3. **Consistent Access**: Always access config values through the config object, not local copies
4. **Documentation**: Update this documentation when adding new configuration options
5. **Testing**: Test configuration changes with the validation script

## Future Extensions

The configuration system can be easily extended with:

- Device-specific settings (based on model detection)
- Environment-specific configurations (development vs. production)
- User-configurable timeouts and retry logic
- Feature flags for optional functionality
- Logging configuration and verbosity levels