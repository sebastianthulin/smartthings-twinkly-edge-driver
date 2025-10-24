-- Effect Manager Feature Implementation
-- Manages predefined static effects only (simplified approach - no device API calls)

local class = require "vendor.30log"
local StaticEffects = require "features.effects.static_effects"

local EffectManager = class("EffectManager")

function EffectManager:init(http_client, auth_service, logger)
  self._http_client = http_client
  self._auth_service = auth_service
  self._logger = logger
  
  -- Initialize only static effects - no device API discovery
  self._static_effects = StaticEffects:new()
end

-- List available effects (predefined static list only)
function EffectManager:list_effects(ip, effect_type)
  -- Always return static effects - no device API discovery
  local static_list = self._static_effects:list_effects()
  local list = {}
  
  for _, effect in ipairs(static_list) do
    effect.type = "static"
    table.insert(list, effect)
  end

  return list
end

-- Activate a specific effect by ID (static effects only)
function EffectManager:set_effect(ip, effect_id, effect_type)
  if not effect_id then
    return nil, "Effect ID is required"
  end
  
  self._logger:debug("Setting static effect " .. tostring(effect_id) .. " on " .. tostring(ip))

  -- Validate effect ID exists in static list
  if not self._static_effects:is_valid_effect_id(effect_id) then
    return nil, "Invalid effect ID: " .. tostring(effect_id)
  end
  
  -- Set mode to effect first
  local ModeControl = require "features.device_control.mode_control"
  local mode_handler = ModeControl:new(self._http_client, self._auth_service, self._logger)
  local ok, err = mode_handler:set_mode(ip, "effect")
  if not ok then 
    return nil, err 
  end
  
  -- Use direct HTTP request to activate effect (simplified approach)
  local payload = {effect_id = effect_id}
  local AuthenticatedRequestHandler = require "features.shared.authenticated_request_handler"
  local handler = AuthenticatedRequestHandler:new(self._http_client, self._auth_service, self._logger)
  
  local ok, code, status, body = handler:make_request(
    ip, "/xled/v1/led/effects/current", "POST", payload)
  
  if ok and code == 200 then
    return true
  else
    return nil, "Failed to set effect: " .. tostring(status or "Unknown error")
  end
end

-- Get current effect information (static effects only)
function EffectManager:get_effect(ip)
  -- First check if device is in effect mode
  local ModeControl = require "features.device_control.mode_control"
  local mode_handler = ModeControl:new(self._http_client, self._auth_service, self._logger)
  local mode = mode_handler:get_mode(ip)
  
  if not mode then
    return nil, "Unable to get device mode"
  end
  
  if mode == "effect" then
    -- Device is in effect mode - try to get current effect via API
    local AuthenticatedRequestHandler = require "features.shared.authenticated_request_handler"
    local handler = AuthenticatedRequestHandler:new(self._http_client, self._auth_service, self._logger)
    
    local ok, code, status, body = handler:make_request(
      ip, "/xled/v1/led/effects/current", "GET")
    
    if ok and code == 200 and body then
      local current_effect = {id = body.effect_id}
      
      -- Enhance with static effect information if available
      local static_effect = self._static_effects:get_effect_by_id(current_effect.id)
      if static_effect then
        current_effect.name = static_effect.name
        current_effect.description = static_effect.description
        current_effect.type = "static"
      end
      return current_effect
    else
      return nil, "Unable to get current effect from device"
    end
  else
    return nil, "Device is not in effect mode (current mode: " .. tostring(mode) .. ")"
  end
end

return EffectManager
