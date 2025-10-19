-- Device Service Implementation  
-- Orchestrates device control features using dependency injection

local class = require "vendor.30log"
local interfaces = require "interfaces"
local ModeControl = require "features.device_control.mode_control"
local BrightnessControl = require "features.device_control.brightness_control"
local ColorControl = require "features.device_control.color_control"
local EffectManager = require "features.effects.effect_manager"

local DeviceService = interfaces.IDeviceService:extend("DeviceService")

function DeviceService:init(http_client, auth_service, color_converter, logger)
  self._http_client = http_client
  self._auth_service = auth_service
  self._color_converter = color_converter
  self._logger = logger
  
  -- Initialize device control features
  self._mode_control = ModeControl:new(http_client, auth_service, logger)
  self._brightness_control = BrightnessControl:new(http_client, auth_service, logger)
  self._color_control = ColorControl:new(http_client, auth_service, color_converter, logger)
  self._effect_manager = EffectManager:new(http_client, auth_service, logger)
end

-- Set device mode (on/off/movie/color/etc)
function DeviceService:set_mode(ip, mode)
  return self._mode_control:set_mode(ip, mode)
end

-- Get current device mode
function DeviceService:get_mode(ip)
  return self._mode_control:get_mode(ip)
end

-- Set brightness level (0-100)
function DeviceService:set_brightness(ip, level)
  return self._brightness_control:set_brightness(ip, level)
end

-- Get current brightness level
function DeviceService:get_brightness(ip)
  return self._brightness_control:get_brightness(ip)
end

-- Set RGB color
function DeviceService:set_color_rgb(ip, red, green, blue)
  -- First set mode to color
  local ok, err = self:set_mode(ip, "color")
  if not ok then 
    return nil, err 
  end
  
  return self._color_control:set_color_rgb(ip, red, green, blue)
end

-- Set HSV color (converts to RGB internally)
function DeviceService:set_color_hsv(ip, hue, saturation, value)
  return self._color_control:set_color_hsv(ip, hue, saturation, value)
end

-- Get current color
function DeviceService:get_color(ip)
  return self._color_control:get_color(ip)
end

-- List available effects on device - firmware 2.9.1+ only
function DeviceService:list_effects(ip, effect_type)
  return self._effect_manager:list_effects(ip, effect_type)
end

-- Activate a specific effect by ID - firmware 2.9.1+ only
function DeviceService:set_effect(ip, effect_id, effect_type)
  return self._effect_manager:set_effect(ip, effect_id, effect_type)
end



return DeviceService
