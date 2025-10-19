-- Scenes Service Implementation  
-- Provides comprehensive scene management for Twinkly devices
-- Scenes combine effect_id, brightness, and color for complete lighting configurations

local class = require "vendor.30log"
local interfaces = require "interfaces"
local json = require "dkjson"

local ScenesService = interfaces.ISceneService:extend("ScenesService")

function ScenesService:init(device_service, logger)
  self._device_service = device_service
  self._logger = logger
  self._predefined_scenes = self:_load_predefined_scenes()
end

-- Load all 78 predefined scenes matching Twinkly app effects
function ScenesService:_load_predefined_scenes()
  return {
    -- Rainbow Effects (12 scenes)
    {id = "rainbow_slow", name = "Rainbow Slow", category = "rainbow", effect_id = 1, brightness = 80, color = {red = 255, green = 128, blue = 0}},
    {id = "rainbow_fast", name = "Rainbow Fast", category = "rainbow", effect_id = 2, brightness = 100, color = {red = 255, green = 0, blue = 128}},
    {id = "rainbow_fade", name = "Rainbow Fade", category = "rainbow", effect_id = 3, brightness = 90, color = {red = 128, green = 255, blue = 0}},
    {id = "rainbow_wave", name = "Rainbow Wave", category = "rainbow", effect_id = 4, brightness = 85, color = {red = 0, green = 255, blue = 128}},
    {id = "rainbow_pulse", name = "Rainbow Pulse", category = "rainbow", effect_id = 5, brightness = 95, color = {red = 255, green = 255, blue = 0}},
    {id = "rainbow_spiral", name = "Rainbow Spiral", category = "rainbow", effect_id = 6, brightness = 75, color = {red = 255, green = 0, blue = 255}},
    {id = "rainbow_chase", name = "Rainbow Chase", category = "rainbow", effect_id = 7, brightness = 100, color = {red = 128, green = 0, blue = 255}},
    {id = "rainbow_sparkle", name = "Rainbow Sparkle", category = "rainbow", effect_id = 8, brightness = 85, color = {red = 0, green = 128, blue = 255}},
    {id = "rainbow_ripple", name = "Rainbow Ripple", category = "rainbow", effect_id = 9, brightness = 90, color = {red = 255, green = 128, blue = 128}},
    {id = "rainbow_burst", name = "Rainbow Burst", category = "rainbow", effect_id = 10, brightness = 100, color = {red = 128, green = 255, blue = 128}},
    {id = "rainbow_flow", name = "Rainbow Flow", category = "rainbow", effect_id = 11, brightness = 80, color = {red = 128, green = 128, blue = 255}},
    {id = "rainbow_cascade", name = "Rainbow Cascade", category = "rainbow", effect_id = 12, brightness = 95, color = {red = 255, green = 255, blue = 128}},

    -- Sparkle Effects (10 scenes)
    {id = "sparkle_white", name = "Sparkle White", category = "sparkle", effect_id = 13, brightness = 100, color = {red = 255, green = 255, blue = 255}},
    {id = "sparkle_multicolor", name = "Sparkle Multicolor", category = "sparkle", effect_id = 14, brightness = 90, color = {red = 255, green = 128, blue = 64}},
    {id = "sparkle_gold", name = "Sparkle Gold", category = "sparkle", effect_id = 15, brightness = 85, color = {red = 255, green = 215, blue = 0}},
    {id = "sparkle_blue", name = "Sparkle Blue", category = "sparkle", effect_id = 16, brightness = 95, color = {red = 0, green = 100, blue = 255}},
    {id = "sparkle_red", name = "Sparkle Red", category = "sparkle", effect_id = 17, brightness = 90, color = {red = 255, green = 0, blue = 0}},
    {id = "sparkle_green", name = "Sparkle Green", category = "sparkle", effect_id = 18, brightness = 85, color = {red = 0, green = 255, blue = 0}},
    {id = "sparkle_purple", name = "Sparkle Purple", category = "sparkle", effect_id = 19, brightness = 80, color = {red = 128, green = 0, blue = 128}},
    {id = "sparkle_silver", name = "Sparkle Silver", category = "sparkle", effect_id = 20, brightness = 95, color = {red = 192, green = 192, blue = 192}},
    {id = "sparkle_warm", name = "Sparkle Warm", category = "sparkle", effect_id = 21, brightness = 75, color = {red = 255, green = 200, blue = 100}},
    {id = "sparkle_cool", name = "Sparkle Cool", category = "sparkle", effect_id = 22, brightness = 85, color = {red = 100, green = 200, blue = 255}},

    -- Twinkle Effects (8 scenes)
    {id = "twinkle_soft", name = "Twinkle Soft", category = "twinkle", effect_id = 23, brightness = 70, color = {red = 255, green = 255, blue = 200}},
    {id = "twinkle_bright", name = "Twinkle Bright", category = "twinkle", effect_id = 24, brightness = 100, color = {red = 255, green = 255, blue = 255}},
    {id = "twinkle_random", name = "Twinkle Random", category = "twinkle", effect_id = 25, brightness = 85, color = {red = 255, green = 128, blue = 255}},
    {id = "twinkle_steady", name = "Twinkle Steady", category = "twinkle", effect_id = 26, brightness = 75, color = {red = 255, green = 255, blue = 128}},
    {id = "twinkle_fast", name = "Twinkle Fast", category = "twinkle", effect_id = 27, brightness = 90, color = {red = 128, green = 255, blue = 255}},
    {id = "twinkle_slow", name = "Twinkle Slow", category = "twinkle", effect_id = 28, brightness = 65, color = {red = 255, green = 200, blue = 200}},
    {id = "twinkle_burst", name = "Twinkle Burst", category = "twinkle", effect_id = 29, brightness = 95, color = {red = 200, green = 255, blue = 200}},
    {id = "twinkle_wave", name = "Twinkle Wave", category = "twinkle", effect_id = 30, brightness = 80, color = {red = 200, green = 200, blue = 255}},

    -- Wave Effects (8 scenes)
    {id = "wave_red", name = "Wave Red", category = "wave", effect_id = 31, brightness = 90, color = {red = 255, green = 0, blue = 0}},
    {id = "wave_blue", name = "Wave Blue", category = "wave", effect_id = 32, brightness = 85, color = {red = 0, green = 0, blue = 255}},
    {id = "wave_green", name = "Wave Green", category = "wave", effect_id = 33, brightness = 80, color = {red = 0, green = 255, blue = 0}},
    {id = "wave_multicolor", name = "Wave Multicolor", category = "wave", effect_id = 34, brightness = 95, color = {red = 255, green = 128, blue = 128}},
    {id = "wave_ocean", name = "Wave Ocean", category = "wave", effect_id = 35, brightness = 75, color = {red = 0, green = 128, blue = 255}},
    {id = "wave_sunset", name = "Wave Sunset", category = "wave", effect_id = 36, brightness = 85, color = {red = 255, green = 100, blue = 0}},
    {id = "wave_aurora", name = "Wave Aurora", category = "wave", effect_id = 37, brightness = 90, color = {red = 128, green = 255, blue = 128}},
    {id = "wave_pulse", name = "Wave Pulse", category = "wave", effect_id = 38, brightness = 100, color = {red = 255, green = 0, blue = 128}},

    -- Solid Colors (10 scenes)
    {id = "solid_red", name = "Solid Red", category = "solid", effect_id = 39, brightness = 100, color = {red = 255, green = 0, blue = 0}},
    {id = "solid_green", name = "Solid Green", category = "solid", effect_id = 40, brightness = 100, color = {red = 0, green = 255, blue = 0}},
    {id = "solid_blue", name = "Solid Blue", category = "solid", effect_id = 41, brightness = 100, color = {red = 0, green = 0, blue = 255}},
    {id = "solid_white", name = "Solid White", category = "solid", effect_id = 42, brightness = 90, color = {red = 255, green = 255, blue = 255}},
    {id = "solid_yellow", name = "Solid Yellow", category = "solid", effect_id = 43, brightness = 95, color = {red = 255, green = 255, blue = 0}},
    {id = "solid_purple", name = "Solid Purple", category = "solid", effect_id = 44, brightness = 85, color = {red = 128, green = 0, blue = 128}},
    {id = "solid_orange", name = "Solid Orange", category = "solid", effect_id = 45, brightness = 90, color = {red = 255, green = 165, blue = 0}},
    {id = "solid_pink", name = "Solid Pink", category = "solid", effect_id = 46, brightness = 80, color = {red = 255, green = 192, blue = 203}},
    {id = "solid_cyan", name = "Solid Cyan", category = "solid", effect_id = 47, brightness = 85, color = {red = 0, green = 255, blue = 255}},
    {id = "solid_warm_white", name = "Solid Warm White", category = "solid", effect_id = 48, brightness = 75, color = {red = 255, green = 244, blue = 229}},

    -- Holiday Themes (10 scenes)
    {id = "christmas_classic", name = "Christmas Classic", category = "holiday", effect_id = 49, brightness = 95, color = {red = 255, green = 0, blue = 0}},
    {id = "christmas_green", name = "Christmas Green", category = "holiday", effect_id = 50, brightness = 90, color = {red = 0, green = 255, blue = 0}},
    {id = "halloween_orange", name = "Halloween Orange", category = "holiday", effect_id = 51, brightness = 100, color = {red = 255, green = 140, blue = 0}},
    {id = "halloween_spooky", name = "Halloween Spooky", category = "holiday", effect_id = 52, brightness = 85, color = {red = 128, green = 0, blue = 128}},
    {id = "valentine_romantic", name = "Valentine Romantic", category = "holiday", effect_id = 53, brightness = 80, color = {red = 255, green = 105, blue = 180}},
    {id = "patriotic_usa", name = "Patriotic USA", category = "holiday", effect_id = 54, brightness = 100, color = {red = 255, green = 0, blue = 0}},
    {id = "easter_pastel", name = "Easter Pastel", category = "holiday", effect_id = 55, brightness = 75, color = {red = 255, green = 182, blue = 193}},
    {id = "thanksgiving_autumn", name = "Thanksgiving Autumn", category = "holiday", effect_id = 56, brightness = 85, color = {red = 255, green = 140, blue = 0}},
    {id = "new_year_gold", name = "New Year Gold", category = "holiday", effect_id = 57, brightness = 100, color = {red = 255, green = 215, blue = 0}},
    {id = "st_patrick_green", name = "St Patrick Green", category = "holiday", effect_id = 58, brightness = 90, color = {red = 0, green = 128, blue = 0}},

    -- Advanced Effects (12 scenes)
    {id = "aurora_borealis", name = "Aurora Borealis", category = "advanced", effect_id = 59, brightness = 85, color = {red = 0, green = 255, blue = 127}},
    {id = "fire_flicker", name = "Fire Flicker", category = "advanced", effect_id = 60, brightness = 90, color = {red = 255, green = 69, blue = 0}},
    {id = "ocean_waves", name = "Ocean Waves", category = "advanced", effect_id = 61, brightness = 80, color = {red = 0, green = 105, blue = 148}},
    {id = "lightning_storm", name = "Lightning Storm", category = "advanced", effect_id = 62, brightness = 100, color = {red = 255, green = 255, blue = 255}},
    {id = "meteor_shower", name = "Meteor Shower", category = "advanced", effect_id = 63, brightness = 95, color = {red = 255, green = 255, blue = 224}},
    {id = "galaxy_swirl", name = "Galaxy Swirl", category = "advanced", effect_id = 64, brightness = 85, color = {red = 75, green = 0, blue = 130}},
    {id = "neon_glow", name = "Neon Glow", category = "advanced", effect_id = 65, brightness = 100, color = {red = 0, green = 255, blue = 255}},
    {id = "plasma_flow", name = "Plasma Flow", category = "advanced", effect_id = 66, brightness = 90, color = {red = 255, green = 20, blue = 147}},
    {id = "crystal_shine", name = "Crystal Shine", category = "advanced", effect_id = 67, brightness = 95, color = {red = 230, green = 230, blue = 250}},
    {id = "magic_sparkle", name = "Magic Sparkle", category = "advanced", effect_id = 68, brightness = 85, color = {red = 138, green = 43, blue = 226}},
    {id = "disco_ball", name = "Disco Ball", category = "advanced", effect_id = 69, brightness = 100, color = {red = 255, green = 215, blue = 0}},
    {id = "laser_show", name = "Laser Show", category = "advanced", effect_id = 70, brightness = 100, color = {red = 255, green = 0, blue = 255}},

    -- Special Effects (8 scenes)
    {id = "candle_flicker", name = "Candle Flicker", category = "special", effect_id = 71, brightness = 60, color = {red = 255, green = 147, blue = 41}},
    {id = "campfire_glow", name = "Campfire Glow", category = "special", effect_id = 72, brightness = 70, color = {red = 255, green = 69, blue = 0}},
    {id = "moonlight_soft", name = "Moonlight Soft", category = "special", effect_id = 73, brightness = 50, color = {red = 173, green = 216, blue = 230}},
    {id = "sunrise_warm", name = "Sunrise Warm", category = "special", effect_id = 74, brightness = 80, color = {red = 255, green = 160, blue = 122}},
    {id = "sunset_cool", name = "Sunset Cool", category = "special", effect_id = 75, brightness = 75, color = {red = 255, green = 99, blue = 71}},
    {id = "starfield_deep", name = "Starfield Deep", category = "special", effect_id = 76, brightness = 65, color = {red = 25, green = 25, blue = 112}},
    {id = "comet_tail", name = "Comet Tail", category = "special", effect_id = 77, brightness = 90, color = {red = 255, green = 255, blue = 240}},
    {id = "energy_pulse", name = "Energy Pulse", category = "special", effect_id = 78, brightness = 95, color = {red = 0, green = 255, blue = 127}}
  }
end

-- List all available scenes or filter by category
function ScenesService:list_scenes(category)
  local scenes = {}
  
  for _, scene in ipairs(self._predefined_scenes) do
    if not category or scene.category == category then
      table.insert(scenes, {
        id = scene.id,
        name = scene.name,
        category = scene.category,
        description = scene.description or ("A " .. scene.category .. " effect")
      })
    end
  end
  
  self._logger:debug("Found " .. #scenes .. " scenes" .. (category and (" in category: " .. category) or ""))
  return scenes
end

-- Get available scene categories
function ScenesService:get_categories()
  local categories = {}
  local seen = {}
  
  for _, scene in ipairs(self._predefined_scenes) do
    if not seen[scene.category] then
      table.insert(categories, scene.category)
      seen[scene.category] = true
    end
  end
  
  return categories
end

-- Activate a specific scene by ID
function ScenesService:activate_scene(ip, scene_id)
  if not scene_id then
    return nil, "Scene ID is required"
  end
  
  -- Find the scene
  local scene = nil
  for _, s in ipairs(self._predefined_scenes) do
    if s.id == scene_id then
      scene = s
      break
    end
  end
  
  if not scene then
    return nil, "Scene not found: " .. tostring(scene_id)
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
  local color_ok, color_err = self._device_service:set_color(ip, scene.color.red, scene.color.green, scene.color.blue)
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
function ScenesService:get_current_scene(ip)
  -- Get current device state
  local mode = self._device_service:get_mode(ip)
  local effect_info = self._device_service:get_effect(ip)
  local brightness = self._device_service:get_brightness(ip)
  local color = self._device_service:get_color(ip)
  
  if mode ~= "effect" or not effect_info then
    return nil, "Device is not in effect mode or effect information unavailable"
  end
  
  -- Try to match current state to a predefined scene
  for _, scene in ipairs(self._predefined_scenes) do
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

-- Get scene by ID
function ScenesService:get_scene_by_id(scene_id)
  for _, scene in ipairs(self._predefined_scenes) do
    if scene.id == scene_id then
      return scene
    end
  end
  return nil
end

-- Get all predefined scenes
function ScenesService:get_predefined_scenes()
  return self._predefined_scenes
end

return ScenesService