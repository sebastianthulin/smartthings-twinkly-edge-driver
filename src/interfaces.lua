-- Interfaces for Twinkly driver using 30log framework
-- This file defines the contracts that classes must implement

local class = require "vendor.30log"

local interfaces = {}

-- IHttpClient interface - for HTTP communication abstraction
interfaces.IHttpClient = class("IHttpClient", {
  -- Abstract methods that must be implemented
  request = function(self, params)
    error("IHttpClient:request() must be implemented by concrete class")
  end
})

-- ILogger interface - for logging abstraction  
interfaces.ILogger = class("ILogger", {
  debug = function(self, ...)
    error("ILogger:debug() must be implemented by concrete class") 
  end,
  info = function(self, ...)
    error("ILogger:info() must be implemented by concrete class")
  end,
  warn = function(self, ...)
    error("ILogger:warn() must be implemented by concrete class")
  end,
  error = function(self, ...)
    error("ILogger:error() must be implemented by concrete class")
  end
})

-- IAuthenticationService interface - for authentication management
interfaces.IAuthenticationService = class("IAuthenticationService", {
  login = function(self, ip)
    error("IAuthenticationService:login() must be implemented by concrete class")
  end,
  ensure_token = function(self, ip)
    error("IAuthenticationService:ensure_token() must be implemented by concrete class")
  end,
  clear_token = function(self, ip)
    error("IAuthenticationService:clear_token() must be implemented by concrete class")
  end
})

-- IDeviceService interface - for device control operations
interfaces.IDeviceService = class("IDeviceService", {
  set_mode = function(self, ip, mode)
    error("IDeviceService:set_mode() must be implemented by concrete class")
  end,
  get_mode = function(self, ip)
    error("IDeviceService:get_mode() must be implemented by concrete class")
  end,
  set_brightness = function(self, ip, level)
    error("IDeviceService:set_brightness() must be implemented by concrete class")
  end,
  get_brightness = function(self, ip)
    error("IDeviceService:get_brightness() must be implemented by concrete class")
  end,
  set_color_rgb = function(self, ip, red, green, blue)
    error("IDeviceService:set_color_rgb() must be implemented by concrete class")
  end,
  set_color_hsv = function(self, ip, hue, saturation, value)
    error("IDeviceService:set_color_hsv() must be implemented by concrete class")
  end,
  get_color = function(self, ip)
    error("IDeviceService:get_color() must be implemented by concrete class")
  end
})

-- IColorConverter interface - for color conversion utilities
interfaces.IColorConverter = class("IColorConverter", {
  hsv_to_rgb = function(self, hue, saturation, value)
    error("IColorConverter:hsv_to_rgb() must be implemented by concrete class")
  end,
  rgb_to_hsv = function(self, red, green, blue)
    error("IColorConverter:rgb_to_hsv() must be implemented by concrete class")
  end
})

-- IServiceContainer interface - for dependency injection
interfaces.IServiceContainer = class("IServiceContainer", {
  register = function(self, name, service)
    error("IServiceContainer:register() must be implemented by concrete class")
  end,
  resolve = function(self, name)
    error("IServiceContainer:resolve() must be implemented by concrete class")
  end,
  register_singleton = function(self, name, factory)
    error("IServiceContainer:register_singleton() must be implemented by concrete class")
  end
})

return interfaces