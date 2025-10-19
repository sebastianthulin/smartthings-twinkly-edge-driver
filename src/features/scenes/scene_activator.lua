-- Scene Activator Feature Implementation
-- Handles scene activation and device state management

local class = require "vendor.30log"

local SceneActivator = class("SceneActivator")

function SceneActivator:init(device_service, logger)
  self._device_service = device_service
  self._logger = logger
end

-- Activate a specific scene by ID
function SceneActivator:activate_scene(ip, scene)
  if not scene then
    return nil, "Scene is required"
  end
  
  self._logger:info("Activating scene: " .. scene.name .. " (ID: " .. scene.id .. ")")
  
  -- Set device to effect mode first
  local ok, err = self._device_service:set_mode(ip, "effect")
  if not ok then
    return nil, "Failed to set effect mode: " .. tostring(err)
  end
  
  -- Set the effect
  local effect_ok, effect_err = self._device_service:set_effect(ip, scene.effect_id, "builtin")
  if not effect_ok then
    return nil, "Failed to set effect: " .. tostring(effect_err)
  end
  
  -- Set brightness
  local brightness_ok, brightness_err = self._device_service:set_brightness(ip, scene.brightness)
  if not brightness_ok then
    self._logger:warn("Failed to set brightness, continuing: " .. tostring(brightness_err))
  end
  
  -- Set color
  local color_ok, color_err = self._device_service:set_color_rgb(ip, scene.color.red, scene.color.green, scene.color.blue)
  if not color_ok then
    self._logger:warn("Failed to set color, continuing: " .. tostring(color_err))
  end
  
  return {
    scene_id = scene.id,
    scene_name = scene.name,
    effect_id = scene.effect_id,
    brightness = scene.brightness,
    color = scene.color
  }
end

-- Get current scene information (best effort based on device state)
function SceneActivator:get_current_scene(ip, scene_loader)
  -- Get current device state
  local mode = self._device_service:get_mode(ip)
  local effect_info = self._device_service:get_effect(ip)
  local brightness = self._device_service:get_brightness(ip)
  local color = self._device_service:get_color(ip)
  
  if mode ~= "effect" or not effect_info then
    return nil, "Device is not in effect mode or effect information unavailable"
  end
  
  -- Try to match current state to a predefined scene
  local predefined_scenes = scene_loader:get_predefined_scenes()
  for _, scene in ipairs(predefined_scenes) do
    if scene.effect_id == effect_info.id then
      return {
        scene_id = scene.id,
        scene_name = scene.name,
        category = scene.category,
        effect_id = scene.effect_id,
        current_brightness = brightness,
        current_color = color,
        predefined_brightness = scene.brightness,
        predefined_color = scene.color,
        is_exact_match = (brightness == scene.brightness and 
                         color and color.red == scene.color.red and 
                         color.green == scene.color.green and 
                         color.blue == scene.color.blue)
      }
    end
  end
  
  return nil, "Current effect does not match any predefined scene"
end

return SceneActivator
