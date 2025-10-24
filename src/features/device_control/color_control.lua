-- Color Control Feature Implementation
-- Handles RGB and HSV color operations

local class = require "vendor.30log"
local AuthenticatedRequestHandler = require "features.shared.authenticated_request_handler"

local ColorControl = class("ColorControl")

function ColorControl:init(http_client, auth_service, color_converter, logger)
  self._request_handler = AuthenticatedRequestHandler:new(http_client, auth_service, logger)
  self._color_converter = color_converter
  self._logger = logger
end

-- Set RGB color
function ColorControl:set_color_rgb(ip, red, green, blue)
  -- Validate input
  if not self._color_converter:validate_rgb(red, green, blue) then
    return nil, "Invalid RGB values"
  end
  
  self._logger:debug(string.format("Setting RGB(%d,%d,%d) -> %s", red, green, blue, ip))
  
  local payload = { red = red, green = green, blue = blue }
  local ok, code, status, body = self._request_handler:make_request(
    ip, "/xled/v1/led/color", "POST", payload)
  
  if not ok then 
    return nil, status 
  end
  return true, body
end

-- Set HSV color (converts to RGB internally)
function ColorControl:set_color_hsv(ip, hue, saturation, value)
  -- Normalize inputs
  saturation = (saturation or 0) / 100  -- Convert percentage to 0-1
  value = (value or 100) / 100          -- Convert percentage to 0-1  
  hue = hue or 0                        -- Hue stays 0-360
  
  -- Validate normalized values
  if not self._color_converter:validate_hsv(hue, saturation, value) then
    return nil, "Invalid HSV values"
  end
  
  local r, g, b = self._color_converter:hsv_to_rgb(hue, saturation, value)
  return self:set_color_rgb(ip, r, g, b)
end

-- Get current color
function ColorControl:get_color(ip)
  local ok, code, status, body = self._request_handler:make_request(
    ip, "/xled/v1/led/color", "GET")
  
  if not ok then 
    return nil 
  end
  
  local json = require "dkjson"
  local decoded = json.decode(body)
  if decoded and decoded.red and decoded.green and decoded.blue then
    return {
      red = decoded.red,
      green = decoded.green, 
      blue = decoded.blue
    }
  end
  
  return nil
end

return ColorControl
