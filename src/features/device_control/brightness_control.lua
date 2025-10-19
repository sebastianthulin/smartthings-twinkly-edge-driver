-- Brightness Control Feature Implementation
-- Handles brightness level operations

local class = require "vendor.30log"
local AuthenticatedRequestHandler = require "features.shared.authenticated_request_handler"

local BrightnessControl = class("BrightnessControl")

function BrightnessControl:init(http_client, auth_service, logger)
  self._request_handler = AuthenticatedRequestHandler:new(http_client, auth_service, logger)
  self._logger = logger
end

-- Set brightness level (0-100)
function BrightnessControl:set_brightness(ip, level)
  level = math.max(0, math.min(100, level or 0))
  
  local ok, code, status, body = self._request_handler:make_request(
    ip, "/xled/v1/led/out/brightness", "POST", { value = level })
  
  if not ok then 
    return nil, status 
  end
  return true, body
end

-- Get current brightness level
function BrightnessControl:get_brightness(ip)
  local ok, code, status, body = self._request_handler:make_request(
    ip, "/xled/v1/led/out/brightness", "GET")
  
  if not ok then 
    return nil 
  end
  
  local json = require "dkjson"
  local decoded = json.decode(body)
  return decoded and decoded.value or 0
end

return BrightnessControl
