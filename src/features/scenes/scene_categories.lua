-- Scene Categories Feature Implementation
-- Handles scene categorization and filtering

local class = require "vendor.30log"

local SceneCategories = class("SceneCategories")

function SceneCategories:init(scene_loader)
  self._scene_loader = scene_loader
end

-- Get available scene categories
function SceneCategories:get_categories()
  local categories = {}
  local seen = {}
  local predefined_scenes = self._scene_loader:get_predefined_scenes()
  
  for _, scene in ipairs(predefined_scenes) do
    if not seen[scene.category] then
      table.insert(categories, scene.category)
      seen[scene.category] = true
    end
  end
  
  return categories
end

-- Get scenes by category
function SceneCategories:get_scenes_by_category(category)
  return self._scene_loader:list_scenes(category)
end

-- Get category statistics
function SceneCategories:get_category_stats()
  local stats = {}
  local predefined_scenes = self._scene_loader:get_predefined_scenes()
  
  for _, scene in ipairs(predefined_scenes) do
    if not stats[scene.category] then
      stats[scene.category] = 0
    end
    stats[scene.category] = stats[scene.category] + 1
  end
  
  return stats
end

return SceneCategories
