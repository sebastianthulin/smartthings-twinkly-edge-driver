-- Color Converter Service Implementation
-- Orchestrates color conversion features using dependency injection

local class = require "src.vendor.30log"
local interfaces = require "src.interfaces"
local RgbConverter = require "src.features.color.rgb_converter"
local HsvConverter = require "src.features.color.hsv_converter"
local ColorValidator = require "src.features.color.color_validator"

local ColorConverter = interfaces.IColorConverter:extend("ColorConverter")

function ColorConverter:init()
  self._rgb_converter = RgbConverter:new()
  self._hsv_converter = HsvConverter:new()
  self._validator = ColorValidator:new()
end

-- Convert HSV to RGB with gamma correction and saturation scaling
function ColorConverter:hsv_to_rgb(hue, saturation, value)
  return self._hsv_converter:hsv_to_rgb(hue, saturation, value)
end

-- Convert RGB to HSV (useful for reverse operations)
function ColorConverter:rgb_to_hsv(red, green, blue)
  return self._rgb_converter:rgb_to_hsv(red, green, blue)
end

-- Utility method to validate RGB values
function ColorConverter:validate_rgb(red, green, blue)
  return self._validator:validate_rgb(red, green, blue)
end

-- Utility method to validate HSV values  
function ColorConverter:validate_hsv(hue, saturation, value)
  return self._validator:validate_hsv(hue, saturation, value)
end

-- Additional utility methods
function ColorConverter:validate_brightness(level)
  return self._validator:validate_brightness(level)
end

function ColorConverter:normalize_rgb(red, green, blue)
  return self._validator:normalize_rgb(red, green, blue)
end

function ColorConverter:normalize_hsv(hue, saturation, value)
  return self._validator:normalize_hsv(hue, saturation, value)
end

return ColorConverter
