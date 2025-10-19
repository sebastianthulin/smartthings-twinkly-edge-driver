-- Scenes Service Implementation  
-- Orchestrates scene management features using dependency injection

local class = require "vendor.30log"
local interfaces = require "interfaces"
local SceneLoader = require "features.scenes.scene_loader"
local SceneActivator = require "features.scenes.scene_activator"
local SceneCategories = require "features.scenes.scene_categories"

local ScenesService = interfaces.ISceneService:extend("ScenesService")

function ScenesService:init(device_service, logger)
  self._device_service = device_service
  self._logger = logger
  
  -- Initialize scene features
  self._scene_loader = SceneLoader:new()
  self._scene_activator = SceneActivator:new(device_service, logger)
  self._scene_categories = SceneCategories:new(self._scene_loader)
end

-- List all available scenes or filter by category
function ScenesService:list_scenes(category)
  local scenes = self._scene_loader:list_scenes(category)
  self._logger:debug("Found " .. #scenes .. " scenes" .. (category and (" in category: " .. category) or ""))
  return scenes
end

-- Get available scene categories
function ScenesService:get_categories()
  return self._scene_categories:get_categories()
end

-- Activate a specific scene by ID
function ScenesService:activate_scene(ip, scene_id)
  if not scene_id then
    return nil, "Scene ID is required"
  end
  
  -- Find the scene
  local scene = self._scene_loader:get_scene_by_id(scene_id)
  if not scene then
    return nil, "Scene not found: " .. tostring(scene_id)
  end
  
  return self._scene_activator:activate_scene(ip, scene)
end

-- Get current scene information (best effort based on device state)
function ScenesService:get_current_scene(ip)
  return self._scene_activator:get_current_scene(ip, self._scene_loader)
end

-- Get scene by ID
function ScenesService:get_scene_by_id(scene_id)
  return self._scene_loader:get_scene_by_id(scene_id)
end

-- Get all predefined scenes
function ScenesService:get_predefined_scenes()
  return self._scene_loader:get_predefined_scenes()
end

return ScenesService
