-- Twinkly API Module - Backward compatible facade using new SOLID architecture
-- This provides the same interface as before but uses dependency injection internally

local ServiceFactory = require "service_factory"

-- Create the controller instance using dependency injection
local controller = ServiceFactory.create_twinkly_controller()

-- Export the same interface as before for backward compatibility
local twinkly = {}

-- Login / token handling
twinkly.login = function(ip)
  return controller:login(ip)
end

twinkly.ensure_token = function(ip)
  return controller:ensure_token(ip)
end

twinkly.clear_token = function(ip)
  return controller:clear_token(ip)
end

-- Control (on/off, effects, etc.)
twinkly.set_mode = function(ip, mode)
  return controller:set_mode(ip, mode)
end

-- Brightness control
twinkly.set_brightness = function(ip, level)
  return controller:set_brightness(ip, level)
end

twinkly.get_brightness = function(ip)
  return controller:get_brightness(ip)
end

-- Color control
twinkly.set_color_rgb = function(ip, red, green, blue)
  return controller:set_color_rgb(ip, red, green, blue)
end

twinkly.set_color_hsv = function(ip, hue, saturation, value)
  return controller:set_color_hsv(ip, hue, saturation, value)
end

twinkly.get_color = function(ip)
  return controller:get_color(ip)
end

-- Status / mode query
twinkly.get_mode = function(ip)
  return controller:get_mode(ip)
end

-- Expose the controller for advanced usage
twinkly._controller = controller

-- Health check function (new functionality enabled by clean architecture)
twinkly.health_check = function(ip)
  return controller:health_check(ip)
end

return twinkly