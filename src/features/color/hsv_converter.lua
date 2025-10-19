-- HSV Converter Feature Implementation
-- Handles HSV color operations and validation

local class = require "vendor.30log"
local config = require "twinkly.config"

local HsvConverter = class("HsvConverter")

function HsvConverter:init()
  -- No special initialization needed
end

-- Convert HSV to RGB with gamma correction and saturation scaling
function HsvConverter:hsv_to_rgb(hue, saturation, value)
  -- Input validation
  hue = math.max(0, math.min(360, hue or 0))
  saturation = math.max(0, math.min(1, saturation or 0))
  value = math.max(0, math.min(1, value or 1))
  
  -- Apply saturation scaling for better color appearance
  saturation = math.pow(saturation, 1 / config.color.saturation_scale)
  
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
  r = math.pow(r + m, 1 / config.color.gamma)
  g = math.pow(g + m, 1 / config.color.gamma)
  b = math.pow(b + m, 1 / config.color.gamma)
  
  -- Convert to 0-255 range and round
  return math.floor(r * 255 + 0.5), 
         math.floor(g * 255 + 0.5), 
         math.floor(b * 255 + 0.5)
end

-- Utility method to validate HSV values  
function HsvConverter:validate_hsv(hue, saturation, value)
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

return HsvConverter
