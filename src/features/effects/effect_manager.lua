-- Effect Manager Feature Implementation
-- Orchestrates static effects and movie management

local class = require "vendor.30log"
local StaticEffects = require "features.effects.static_effects"
local EffectController = require "features.effects.effect_controller"
local MovieManager = require "features.effects.movie_manager"

local EffectManager = class("EffectManager")

function EffectManager:init(http_client, auth_service, logger)
  self._http_client = http_client
  self._auth_service = auth_service
  self._logger = logger
  
  -- Initialize effect handlers
  self._static_effects = StaticEffects:new()
  self._effect_controller = EffectController:new(http_client, auth_service, logger)
  self._movie_manager = MovieManager:new(http_client, auth_service, logger)
end

-- List available effects (static list, not from device)
function EffectManager:list_effects(ip, effect_type)
  effect_type = effect_type or "all"  -- default to all effects
  
  local list = {}

  -- Get static effects (always available)
  if effect_type == "all" or effect_type == "builtin" or effect_type == "static" then
    local static_list = self._static_effects:list_effects()
    for _, effect in ipairs(static_list) do
      effect.type = "static"
      table.insert(list, effect)
    end
  end

  -- Get movies from device (if requested)
  if effect_type == "all" or effect_type == "user" or effect_type == "movie" then
    local movie_list = self._movie_manager:list_movies(ip)
    for _, movie in ipairs(movie_list) do
      movie.type = "movie"
      table.insert(list, movie)
    end
  end

  return list
end

-- Activate a specific effect by ID
function EffectManager:set_effect(ip, effect_id, effect_type)
  if not effect_id then
    return nil, "Effect ID is required"
  end
  
  self._logger:debug("Setting effect " .. tostring(effect_id) .. " (" .. tostring(effect_type or "static") .. ") on " .. tostring(ip))

  -- Default to static effects
  effect_type = effect_type or "static"

  if effect_type == "static" or effect_type == "builtin" then
    -- For static effects: validate ID and set effect mode
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
    
    return self._effect_controller:set_effect(ip, effect_id)
  elseif effect_type == "movie" then
    -- For movies: set mode to movie first
    local ModeControl = require "features.device_control.mode_control"
    local mode_handler = ModeControl:new(self._http_client, self._auth_service, self._logger)
    local ok, err = mode_handler:set_mode(ip, "movie")
    if not ok then 
      return nil, err 
    end
    
    return self._movie_manager:set_movie(ip, effect_id)
  else
    return nil, "Unknown effect type: " .. tostring(effect_type)
  end
end

-- Get current effect information
function EffectManager:get_effect(ip)
  -- First check if device is in effect mode
  local ModeControl = require "features.device_control.mode_control"
  local mode_handler = ModeControl:new(self._http_client, self._auth_service, self._logger)
  local mode = mode_handler:get_mode(ip)
  
  if not mode then
    return nil, "Unable to get device mode"
  end
  
  if mode == "effect" then
    -- Device is in effect mode - check current effect
    return self._effect_controller:get_current_effect(ip)
  elseif mode == "movie" then
    -- Device is in movie mode - check current movie
    return self._movie_manager:get_current_movie(ip)
  else
    return nil, "Device is not in effect or movie mode (current mode: " .. tostring(mode) .. ")"
  end
end

return EffectManager
