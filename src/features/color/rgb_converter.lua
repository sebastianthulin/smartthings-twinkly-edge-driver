-- RGB Converter Feature Implementation
-- Handles RGB color operations and validation

local class = require "vendor.30log"

local RgbConverter = class("RgbConverter")

function RgbConverter:init()
  -- No special initialization needed
end

-- Utility method to validate RGB values
function RgbConverter:validate_rgb(red, green, blue)
  local function is_valid_rgb_component(val)
    return type(val) == "number" and val >= 0 and val <= 255
  end
  
  return is_valid_rgb_component(red) and 
         is_valid_rgb_component(green) and 
         is_valid_rgb_component(blue)
end

-- Convert RGB to HSV (useful for reverse operations)
function RgbConverter:rgb_to_hsv(red, green, blue)
  -- Input validation and normalization
  red = math.max(0, math.min(255, red or 0)) / 255
  green = math.max(0, math.min(255, green or 0)) / 255
  blue = math.max(0, math.min(255, blue or 0)) / 255
  
  local max_val = math.max(red, green, blue)
  local min_val = math.min(red, green, blue)
  local delta = max_val - min_val
  
  local hue = 0
  local saturation = 0
  local value = max_val
  
  if delta > 0 then
    saturation = delta / max_val
    
    if max_val == red then
      hue = 60 * (((green - blue) / delta) % 6)
    elseif max_val == green then
      hue = 60 * ((blue - red) / delta + 2)
    else
      hue = 60 * ((red - green) / delta + 4)
    end
  end
  
  -- Ensure hue is positive
  if hue < 0 then
    hue = hue + 360
  end
  
  return hue, saturation, value
end

return RgbConverter
