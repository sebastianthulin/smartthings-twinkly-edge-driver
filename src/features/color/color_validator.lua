-- Color Validator Feature Implementation
-- Provides comprehensive color validation utilities

local class = require "src.vendor.30log"

local ColorValidator = class("ColorValidator")

function ColorValidator:init()
  -- No special initialization needed
end

-- Validate RGB color values
function ColorValidator:validate_rgb(red, green, blue)
  local function is_valid_rgb_component(val)
    return type(val) == "number" and val >= 0 and val <= 255
  end
  
  return is_valid_rgb_component(red) and 
         is_valid_rgb_component(green) and 
         is_valid_rgb_component(blue)
end

-- Validate HSV color values
function ColorValidator:validate_hsv(hue, saturation, value)
  local function is_valid_hue(h)
    return type(h) == "number" and h >= 0 and h <= 360
  end
  
  local function is_valid_percent(val)
    return type(val) == "number" and val >= 0 and val <= 1
  end
  
  return is_valid_hue(hue) and 
         is_valid_percent(saturation) and 
         is_valid_percent(value)
end

-- Validate brightness level (0-100)
function ColorValidator:validate_brightness(level)
  return type(level) == "number" and level >= 0 and level <= 100
end

-- Normalize RGB values to 0-255 range
function ColorValidator:normalize_rgb(red, green, blue)
  return math.max(0, math.min(255, red or 0)),
         math.max(0, math.min(255, green or 0)),
         math.max(0, math.min(255, blue or 0))
end

-- Normalize HSV values to proper ranges
function ColorValidator:normalize_hsv(hue, saturation, value)
  return math.max(0, math.min(360, hue or 0)),
         math.max(0, math.min(1, saturation or 0)),
         math.max(0, math.min(1, value or 1))
end

return ColorValidator
