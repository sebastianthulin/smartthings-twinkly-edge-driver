# Testing Guide for Twinkly Edge Driver

This guide explains how to run tests for the Twinkly SmartThings Edge Driver locally without requiring SmartThings infrastructure.

## Quick Start

```bash
# Install Lua 5.3 and dependencies (Ubuntu/Debian)
sudo apt-get install lua5.3 lua5.3-dev luarocks
sudo luarocks install luasocket dkjson luaossl cosock lua-log

# Run all tests (unit tests only, no device required)
npm run test

# Run only unit tests
npm run test:unit

# Run integration tests with your device
IP=192.168.1.45 npm run test:integration
```

## Test Configuration

### Method 1: Environment Variables (Recommended for CI)

```bash
# Set IP for integration tests
export IP=192.168.1.45

# Run tests
npm run test
```

### Method 2: Configuration File (Recommended for Development)

```bash
# Copy and customize the test configuration
cp test-config.example.lua test-config.lua

# Edit test-config.lua with your device settings
vim test-config.lua
```

### Method 3: Environment File

```bash
# Copy and customize the environment file  
cp .env.example .env

# Edit .env with your settings
vim .env
```

## Test Types

### Unit Tests

Unit tests run without requiring a real Twinkly device. They test individual modules with mocked dependencies:

- **Utils Tests**: Test utility functions like base64 generation
- **Config Tests**: Test configuration loading and environment variable handling  
- **Login Tests**: Test authentication logic with mocked HTTP responses
- **Driver Tests**: Test SmartThings driver integration with mocked environment

```bash
npm run test:unit
```

### Integration Tests

Integration tests require a real Twinkly device on your network:

- **Device Tests**: Test actual device communication
- **Mode Control**: Test switching device on/off
- **Brightness Control**: Test brightness adjustment (0-100%)
- **Color Control**: Test RGB and HSV color setting

```bash
IP=192.168.1.45 npm run test:integration
```

## Individual Device Testing (Legacy)

The original device test commands are still available:

```bash
# Basic device control
IP=192.168.1.45 npm run test:on
IP=192.168.1.45 npm run test:off  
IP=192.168.1.45 npm run test:get

# Brightness control
IP=192.168.1.45 LEVEL=75 npm run test:bright

# Color control (HSV)
IP=192.168.1.45 HUE=120 SAT=100 VAL=80 npm run test:color

# Color control (RGB)
IP=192.168.1.45 RED=255 GREEN=0 BLUE=0 npm run test:rgb
```

## Test Framework Features

### Mocked SmartThings Environment

The test framework includes comprehensive mocks for SmartThings components:

- **st.driver**: Driver constructor and timer functions
- **st.capabilities**: Switch, brightness, and color capabilities
- **Device objects**: Field storage and event emission
- **HTTP requests**: Mocked responses for login/authentication

### Configuration Flexibility

Tests support multiple configuration methods with priority order:

1. Environment variables (highest priority)
2. test-config.lua file
3. Built-in defaults (lowest priority)

### Automatic Skipping

Integration tests automatically skip when no device IP is configured, allowing the full test suite to run in CI environments without failing.

## Test Output

### Successful Run
```
Twinkly Edge Driver Test Suite
==============================
Test type: all

=== Running Unit Tests ===
✓ Utils Tests PASSED
✓ Config Tests PASSED  
✓ Login Tests PASSED
✓ Driver Tests PASSED

=== Running Integration Tests ===
✓ Device Integration Tests PASSED

🎉 All tests passed!
```

### Failed Test Example
```
✗ 1. Device responds to get_mode
  Error: Should get a mode from device

Failure details:
1. Device responds to get_mode: Connection refused
```

## Troubleshooting

### Lua Dependencies Missing

```bash
# Install missing dependencies
sudo luarocks install luasocket
sudo luarocks install dkjson
sudo luarocks install luaossl
sudo luarocks install cosock
sudo luarocks install lua-log
```

### Device Connection Issues

- Verify device IP address is correct
- Ensure device is on same network
- Check firewall settings (device uses port 80)
- Verify device is powered on and connected to WiFi

### Permission Issues

```bash
# If luarocks fails with permissions
sudo luarocks install <package>

# Or install to user directory
luarocks --local install <package>
```

## Extending Tests

### Adding Unit Tests

Create new test files in `tests/` directory:

```lua
-- tests/unit-test-mymodule.lua
package.path = package.path .. ";../src/?.lua;./?.lua"
_G.IS_LOCAL_TEST = true

local test_utils = require("test-utils")
local mymodule = require("mymodule")
local test = test_utils.test_framework

test.describe("My test description", function()
  test.assert_equals(mymodule.myfunction(), "expected", "Should return expected value")
end)

if not test.run_all() then
  os.exit(1)
end
```

### Adding Integration Tests

Add tests to `integration-test-device.lua` or create new integration test files.

### Test Configuration

Extend `test-config.example.lua` with new configuration options for your tests.