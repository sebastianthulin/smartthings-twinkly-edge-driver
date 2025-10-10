-- Service Container for Dependency Injection
-- Implements IServiceContainer interface following SOLID principles

local class = require "vendor.30log"
local interfaces = require "interfaces"

local ServiceContainer = interfaces.IServiceContainer:extend("ServiceContainer")

function ServiceContainer:init()
  self._services = {}
  self._singletons = {}
  self._singleton_instances = {}
end

-- Register a service instance
function ServiceContainer:register(name, service)
  assert(name, "Service name is required")
  assert(service, "Service instance is required")
  self._services[name] = service
  return self
end

-- Register a singleton factory function
function ServiceContainer:register_singleton(name, factory)
  assert(name, "Service name is required")
  assert(type(factory) == "function", "Factory must be a function")
  self._singletons[name] = factory
  return self
end

-- Resolve a service by name
function ServiceContainer:resolve(name)
  assert(name, "Service name is required")
  
  -- Check for singleton instance first
  if self._singleton_instances[name] then
    return self._singleton_instances[name]
  end
  
  -- Check for singleton factory
  if self._singletons[name] then
    local instance = self._singletons[name](self)
    self._singleton_instances[name] = instance
    return instance
  end
  
  -- Check for regular service
  if self._services[name] then
    return self._services[name]
  end
  
  error("Service not found: " .. tostring(name))
end

-- Check if service is registered
function ServiceContainer:has(name)
  return self._services[name] ~= nil or 
         self._singletons[name] ~= nil or 
         self._singleton_instances[name] ~= nil
end

-- Clear all services (useful for testing)
function ServiceContainer:clear()
  self._services = {}
  self._singletons = {}
  self._singleton_instances = {}
  return self
end

-- Get all registered service names
function ServiceContainer:get_service_names()
  local names = {}
  for name in pairs(self._services) do
    names[#names + 1] = name
  end
  for name in pairs(self._singletons) do
    names[#names + 1] = name
  end
  for name in pairs(self._singleton_instances) do
    names[#names + 1] = name
  end
  return names
end

return ServiceContainer