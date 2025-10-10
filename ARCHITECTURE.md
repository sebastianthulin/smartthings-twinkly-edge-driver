# Twinkly Driver Architecture Documentation

## Overview

The Twinkly Edge Driver has been redesigned using **SOLID principles** and **dependency injection** to create clean, maintainable, and extensible code. This document explains the new architecture and how to use it.

## Architecture Principles

### SOLID Principles Implementation

- **S**ingle Responsibility: Each class has one clear purpose
- **O**pen/Closed: Extensible through interfaces without modification
- **L**iskov Substitution: Proper inheritance hierarchies with 30log
- **I**nterface Segregation: Specific, focused interfaces
- **D**ependency Inversion: All dependencies injected, not hardcoded

### Key Benefits

- **Better Testability**: Dependency injection enables easy mocking
- **Improved Maintainability**: Clear separation of concerns
- **Enhanced Reusability**: Components can be used independently
- **Easier Extension**: New features can be added without breaking existing code
- **Backward Compatibility**: All existing APIs work exactly as before

## Architecture Overview

```
┌─────────────────┐    ┌──────────────────┐
│   twinkly.lua   │────│ TwinklyController│  (Facade)
│ (Backward API)  │    │                  │
└─────────────────┘    └──────────┬───────┘
                                  │
                       ┌──────────▼──────────┐
                       │ ServiceContainer    │  (Dependency Injection)
                       │                     │
                       └──────────┬──────────┘
                                  │
        ┌─────────────────────────┼─────────────────────────┐
        │                         │                         │
┌───────▼─────────┐    ┌──────────▼──────┐    ┌─────────────▼───────┐
│ DeviceService   │    │ AuthService     │    │ HttpClient          │
│                 │    │                 │    │                     │
└─────────────────┘    └─────────────────┘    └─────────────────────┘
        │                         │                         │
        │              ┌──────────▼──────────┐              │
        │              │ ColorConverter      │              │
        │              │                     │              │
        └──────────────┴─────────────────────┴──────────────┘
                                  │
                       ┌──────────▼──────────┐
                       │ Logger              │
                       │                     │
                       └─────────────────────┘
```

## Core Components

### 1. Interfaces (`src/interfaces.lua`)

Defines contracts that all implementations must follow:

- `IHttpClient` - HTTP communication abstraction
- `ILogger` - Logging abstraction
- `IAuthenticationService` - Token management
- `IDeviceService` - Device operations
- `IColorConverter` - Color conversion utilities
- `IServiceContainer` - Dependency injection

### 2. Service Container (`src/services/container.lua`)

Manages service registration and lifetime:

```lua
local container = ServiceContainer:new()

-- Register singleton service
container:register_singleton("logger", function(c) 
  return Logger:new() 
end)

-- Resolve service
local logger = container:resolve("logger")
```

### 3. Services

#### Logger Service (`src/services/logger.lua`)
Handles logging with fallback for local testing:

```lua
local logger = Logger:new()
logger:info("Message")
logger:debug("Debug info")
```

#### HTTP Client (`src/services/http_client.lua`)
Abstracts HTTP communication:

```lua
local response = http_client:post(url, body, headers)
if response.success then
  print("Status:", response.status_code)
  print("Body:", response.body)
end
```

#### Authentication Service (`src/services/authentication_service.lua`)
Manages Twinkly authentication and tokens:

```lua
local token, err = auth_service:ensure_token("192.168.1.100")
auth_service:clear_token("192.168.1.100") -- Force re-login
```

#### Device Service (`src/services/device_service.lua`)
Handles all device operations:

```lua
device_service:set_mode("192.168.1.100", "movie")
device_service:set_color_rgb("192.168.1.100", 255, 0, 0)
local brightness = device_service:get_brightness("192.168.1.100")
```

#### Color Converter (`src/services/color_converter.lua`)
Converts between color formats with gamma correction:

```lua
local r, g, b = color_converter:hsv_to_rgb(120, 0.8, 1.0)
local h, s, v = color_converter:rgb_to_hsv(255, 128, 0)
```

### 4. Main Controller (`src/twinkly_controller.lua`)

Facade providing clean interface to all functionality:

```lua
local controller = TwinklyController:new(service_container)
controller:set_brightness("192.168.1.100", 75)
local health = controller:health_check("192.168.1.100")
```

### 5. Service Factory (`src/service_factory.lua`)

Configures the entire dependency graph:

```lua
local container = ServiceFactory.create_container()
local controller = ServiceFactory.create_twinkly_controller()
```

## Usage Examples

### Basic Usage (Backward Compatible)

```lua
local twinkly = require "twinkly"

-- All existing functionality works exactly as before
twinkly.set_mode("192.168.1.100", "movie")
twinkly.set_brightness("192.168.1.100", 80)
twinkly.set_color_rgb("192.168.1.100", 255, 0, 0)

-- New functionality
local health = twinkly.health_check("192.168.1.100")
```

### Advanced Usage with Dependency Injection

```lua
local ServiceFactory = require "service_factory"

-- Get the service container
local container = ServiceFactory.create_container()

-- Resolve individual services
local logger = container:resolve("logger")
local device_service = container:resolve("device_service")

-- Use services directly
device_service:set_color_hsv("192.168.1.100", 240, 100, 80)
```

### Creating Custom Services

```lua
local class = require "vendor.30log"

-- Define interface
local ICustomService = class("ICustomService", {
  do_something = function(self)
    error("Must be implemented")
  end
})

-- Implement service
local CustomService = ICustomService:extend("CustomService")

function CustomService:init(logger)
  self._logger = logger
end

function CustomService:do_something()
  self._logger:info("Custom service called")
  return "success"
end

-- Register in container
container:register("custom_service", CustomService:new(logger))
```

### Testing with Mocks

```lua
-- Create mock HTTP client for testing
local MockHttpClient = class("MockHttpClient")

function MockHttpClient:request(params)
  return {
    success = true,
    status_code = 200,
    body = '{"mode": "movie"}'
  }
end

-- Use in test container
local test_container = ServiceContainer:new()
test_container:register("http_client", MockHttpClient:new())
-- ... register other services for testing
```

## Migration Guide

### No Changes Required

If you're using the driver through the existing API, **no changes are required**. All existing code continues to work:

```lua
local twinkly = require "twinkly"
-- All existing calls work exactly as before
```

### Optional Enhancements

Take advantage of new capabilities:

```lua
-- Health checking
local health = twinkly.health_check(ip)
print("Device reachable:", health.can_get_mode)

-- Access to advanced services
local controller = twinkly._controller
local container = controller:get_service_container()
local color_converter = container:resolve("color_converter")
```

## Framework: 30log

The architecture uses the **30log** framework for object-oriented programming in Lua:

- **Classes and Inheritance**: `local MyClass = class("MyClass")`
- **Instance Creation**: `local instance = MyClass:new(args)`
- **Inheritance**: `local Child = Parent:extend("Child")`
- **Mixins**: `MyClass:with(SomeMixin)`

See [30log documentation](https://github.com/Yonaba/30log) for details.

## File Structure

```
src/
├── vendor/
│   └── 30log.lua              # OOP framework
├── services/
│   ├── container.lua          # Dependency injection
│   ├── logger.lua             # Logging service
│   ├── http_client.lua        # HTTP abstraction
│   ├── authentication_service.lua  # Auth management
│   ├── device_service.lua     # Device operations
│   └── color_converter.lua    # Color utilities
├── examples/
│   └── usage_examples.lua     # Architecture examples
├── interfaces.lua             # Service contracts
├── service_factory.lua        # DI configuration
├── twinkly_controller.lua     # Main facade
└── twinkly.lua               # Backward compatible API
```

## Benefits of the New Architecture

1. **Maintainability**: Clear separation makes code easier to understand and modify
2. **Testability**: Dependency injection enables comprehensive unit testing
3. **Extensibility**: New features can be added without breaking existing code
4. **Reusability**: Services can be used independently in different contexts
5. **Quality**: SOLID principles ensure robust, professional code structure
6. **Compatibility**: Existing code continues to work without changes

The new architecture provides a solid foundation for future enhancements while maintaining all existing functionality!