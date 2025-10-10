-- Color Converter Service Implementation
-- Implements IColorConverter interface with HSV/RGB conversions

local class = require "vendor.30log"
local interfaces = require "interfaces"

local ColorConverter = interfaces.IColorConverter:extend("ColorConverter")

-- Adjustable saturation curve factor (higher = more saturation retained)
local SATURATION_SCALE = 1.8

function ColorConverter:init()
  -- No special initialization needed
end

-- Convert HSV to RGB with gamma correction and saturation scaling
function ColorConverter:hsv_to_rgb(hue, saturation, value)
  -- Input validation
  hue = math.max(0, math.min(360, hue or 0))
  saturation = math.max(0, math.min(1, saturation or 0))
  value = math.max(0, math.min(1, value or 1))
  
  -- Apply saturation scaling for better color appearance
  saturation = math.pow(saturation, 1 / SATURATION_SCALE)
  
  local c = value * saturation
  local x = c * (1 - math.abs((hue / 60) % 2 - 1))
  local m = value - c
  local r, g, b
  
  if hue < 60 then 
    r, g, b = c, x, 0
  elseif hue < 120 then 
    r, g, b = x, c, 0
  elseif hue < 180 then 
    r, g, b = 0, c, x
  elseif hue < 240 then 
    r, g, b = 0, x, c
  elseif hue < 300 then 
    r, g, b = x, 0, c
  else 
    r, g, b = c, 0, x 
  end
  
  -- Apply gamma correction for better visual accuracy
  local gamma = 2.2
  r = math.pow(r + m, 1 / gamma)
  g = math.pow(g + m, 1 / gamma)
  b = math.pow(b + m, 1 / gamma)
  
  -- Convert to 0-255 range and round
  return math.floor(r * 255 + 0.5), 
         math.floor(g * 255 + 0.5), 
         math.floor(b * 255 + 0.5)
end

-- Convert RGB to HSV (useful for reverse operations)
function ColorConverter:rgb_to_hsv(red, green, blue)
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

-- Utility method to validate RGB values
function ColorConverter:validate_rgb(red, green, blue)
  local function is_valid_rgb_component(val)
    return type(val) == "number" and val >= 0 and val <= 255
  end
  
  return is_valid_rgb_component(red) and 
         is_valid_rgb_component(green) and 
         is_valid_rgb_component(blue)
end

-- Utility method to validate HSV values  
function ColorConverter:validate_hsv(hue, saturation, value)
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

return ColorConverter