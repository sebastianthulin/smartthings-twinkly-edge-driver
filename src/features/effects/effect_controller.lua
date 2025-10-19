-- Effect Controller Feature Implementation
-- Handles setting effects on the device

local class = require "vendor.30log"
local AuthenticatedRequestHandler = require "features.shared.authenticated_request_handler"

local EffectController = class("EffectController")

function EffectController:init(http_client, auth_service, logger)
  self._request_handler = AuthenticatedRequestHandler:new(http_client, auth_service, logger)
  self._logger = logger
end

-- Set effect on device
function EffectController:set_effect(ip, effect_id)
  if not effect_id then
    return nil, "Effect ID is required"
  end
  
  self._logger:debug("Setting effect " .. tostring(effect_id) .. " on " .. tostring(ip))

  local payload = { effect_id = effect_id }
  local ok, code, status, body = self._request_handler:make_request(
    ip, "/xled/v1/led/effects/current", "POST", payload)
  
  if ok then
    return true, body
  else
    return nil, "Failed to set effect: " .. tostring(status)
  end
end

-- Get current effect from device
function EffectController:get_current_effect(ip)
  local ok, code, status, body = self._request_handler:make_request(
    ip, "/xled/v1/led/effects/current", "GET")
  
  if ok then
    local json = require "dkjson"
    local decoded = json.decode(body)
    if decoded and decoded.effect_id ~= nil then
      return {
        id = decoded.effect_id,
        unique_id = decoded.unique_id,
        name = "Effect " .. decoded.effect_id
      }
    end
  else
    self._logger:debug("Failed to get current effect: " .. tostring(status))
  end
  
  return nil
end

return EffectController
