-- Service Factory for configuring dependency injection
-- Sets up all services and their dependencies according to SOLID principles

local ServiceContainer = require "services.container"
local Logger = require "services.logger"
local HttpClient = require "services.http_client"
local ColorConverter = require "services.color_converter"
local AuthenticationService = require "services.authentication_service"
local DeviceService = require "services.device_service"
local TwinklyController = require "twinkly_controller"

local ServiceFactory = {}

-- Create and configure the service container with all dependencies
function ServiceFactory.create_container()
  local container = ServiceContainer:new()
  
  -- Register base services as singletons
  container:register_singleton("logger", function(c)
    return Logger:new()
  end)
  
  container:register_singleton("http_client", function(c)
    local logger = c:resolve("logger")
    return HttpClient:new(logger)
  end)
  
  container:register_singleton("color_converter", function(c)
    return ColorConverter:new()
  end)
  
  container:register_singleton("utils", function(c)
    return require("twinkly.utils")
  end)
  
  -- Register authentication service with dependencies
  container:register_singleton("auth_service", function(c)
    local http_client = c:resolve("http_client")
    local logger = c:resolve("logger")
    local utils = c:resolve("utils")
    return AuthenticationService:new(http_client, logger, utils)
  end)
  
  -- Register device service with dependencies  
  container:register_singleton("device_service", function(c)
    local http_client = c:resolve("http_client")
    local auth_service = c:resolve("auth_service")
    local color_converter = c:resolve("color_converter")
    local logger = c:resolve("logger")
    return DeviceService:new(http_client, auth_service, color_converter, logger)
  end)
  
  -- Register main controller with dependencies
  container:register_singleton("twinkly_controller", function(c)
    return TwinklyController:new(c)
  end)
  
  return container
end

-- Create a ready-to-use Twinkly controller instance
function ServiceFactory.create_twinkly_controller()
  local container = ServiceFactory.create_container()
  return container:resolve("twinkly_controller")
end

-- Create container with test/mock services for testing
function ServiceFactory.create_test_container()
  local container = ServiceContainer:new()
  
  -- You can register mock services here for testing
  -- This method can be extended when writing tests
  
  return container
end

return ServiceFactory