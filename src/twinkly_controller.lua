-- Twinkly Controller - Main Facade for Twinkly Operations
-- Provides a clean interface while using dependency injection internally

local class = require "vendor.30log" 

local TwinklyController = class("TwinklyController")

function TwinklyController:init(service_container)
  self._container = service_container
  
  -- Resolve dependencies from container
  self._device_service = service_container:resolve("device_service")
  self._auth_service = service_container:resolve("auth_service")
  self._logger = service_container:resolve("logger")
end

-- Authentication methods
function TwinklyController:login(ip)
  return self._auth_service:login(ip)
end

function TwinklyController:ensure_token(ip)
  return self._auth_service:ensure_token(ip)
end

function TwinklyController:clear_token(ip)
  return self._auth_service:clear_token(ip)
end

-- Device mode operations
function TwinklyController:set_mode(ip, mode)
  return self._device_service:set_mode(ip, mode)
end

function TwinklyController:get_mode(ip)
  return self._device_service:get_mode(ip)
end

-- Brightness control
function TwinklyController:set_brightness(ip, level)
  return self._device_service:set_brightness(ip, level)
end

function TwinklyController:get_brightness(ip)
  return self._device_service:get_brightness(ip)
end

-- Color control
function TwinklyController:set_color_rgb(ip, red, green, blue)
  return self._device_service:set_color_rgb(ip, red, green, blue)
end

function TwinklyController:set_color_hsv(ip, hue, saturation, value)
  return self._device_service:set_color_hsv(ip, hue, saturation, value)
end

function TwinklyController:get_color(ip)
  return self._device_service:get_color(ip)
end

-- Service container access for advanced usage
function TwinklyController:get_service_container()
  return self._container
end

-- Health check method
function TwinklyController:health_check(ip)
  local has_cached_token = self._auth_service:has_cached_token(ip)
  local mode_result = self:get_mode(ip)
  
  return {
    ip = ip,
    has_cached_token = has_cached_token,
    can_get_mode = mode_result ~= nil,
    mode = mode_result
  }
end

return TwinklyController