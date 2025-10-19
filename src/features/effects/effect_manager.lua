-- Effect Manager Feature Implementation
-- Orchestrates builtin and user effects operations

local class = require "vendor.30log"

local EffectManager = class("EffectManager")

function EffectManager:init(http_client, auth_service, logger)
  self._http_client = http_client
  self._auth_service = auth_service
  self._logger = logger
  
  -- Initialize effect handlers
  local BuiltinEffects = require "features.effects.builtin_effects"
  local UserEffects = require "features.effects.user_effects"
  
  self._builtin_effects = BuiltinEffects:new(http_client, auth_service, logger)
  self._user_effects = UserEffects:new(http_client, auth_service, logger)
end

-- List available effects on device - firmware 2.9.1+ only
function EffectManager:list_effects(ip, effect_type)
  effect_type = effect_type or "all"  -- default to all effects
  
  local list = {}

  -- Get builtin effects
  if effect_type == "all" or effect_type == "builtin" then
    local builtin_list = self._builtin_effects:list_effects(ip)
    for _, effect in ipairs(builtin_list) do
      table.insert(list, effect)
    end
  end

  -- Get user movies
  if effect_type == "all" or effect_type == "user" then
    local user_list = self._user_effects:list_movies(ip)
    for _, effect in ipairs(user_list) do
      table.insert(list, effect)
    end
  end

  return list
end

-- Activate a specific effect by ID - firmware 2.9.1+ only
function EffectManager:set_effect(ip, effect_id, effect_type)
  if not effect_id then
    return nil, "Effect ID is required"
  end
  
  self._logger:debug("Setting effect " .. tostring(effect_id) .. " (" .. tostring(effect_type or "builtin") .. ") on " .. tostring(ip))

  -- Default to builtin for firmware 2.9.1+
  effect_type = effect_type or "builtin"

  if effect_type == "builtin" then
    -- For builtin effects: set mode to "effect" first
    local ModeControl = require "features.device_control.mode_control"
    local mode_handler = ModeControl:new(self._http_client, self._auth_service, self._logger)
    local ok, err = mode_handler:set_mode(ip, "effect")
    if not ok then 
      return nil, err 
    end
    
    return self._builtin_effects:set_effect(ip, effect_id)
  elseif effect_type == "user" then
    -- For user movies: set mode to "movie" first
    local ModeControl = require "features.device_control.mode_control"
    local mode_handler = ModeControl:new(self._http_client, self._auth_service, self._logger)
    local ok, err = mode_handler:set_mode(ip, "movie")
    if not ok then 
      return nil, err 
    end
    
    return self._user_effects:set_movie(ip, effect_id)
  else
    return nil, "Unknown effect type: " .. tostring(effect_type)
  end
end

-- Get current effect information - firmware 2.9.1+ only
function EffectManager:get_effect(ip)
  -- First check if device is in effect mode
  local mode_control = require "features.device_control.mode_control"
  local mode_handler = mode_control:new(self._http_client, self._auth_service, self._logger)
  local mode = mode_handler:get_mode(ip)
  
  if not mode then
    return nil, "Unable to get device mode"
  end
  
  if mode == "effect" then
    -- Device is in effect mode - check current builtin effect
    return self._builtin_effects:get_current_effect(ip)
  elseif mode == "movie" then
    -- Device is in movie mode - check current user movie
    return self._user_effects:get_current_movie(ip)
  else
    return nil, "Device is not in effect or movie mode (current mode: " .. tostring(mode) .. ")"
  end
end

return EffectManager
