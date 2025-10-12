# Twinkly Edge Driver for Developers
This repository contains a SmartThings Edge driver for controlling Twinkly lights over the local LAN.

Channel Link: https://callaway.smartthings.com/channels/912e7705-ec88-413c-a3ac-1c5ecd9015ba

## Compability
This driver is only tested on the following products: 
- TWKP200RGB-G [Twinkly Candies / Pearl]

## Features
- Auto-discovery via Twinkly UDP broadcasts (port 5555)
- Switch capability (on = movie mode, off = off)
- **Brightness control** (0-100% dimming via switchLevel capability)
- **Color control** (Full RGB/HSV color setting via colorControl capability)
- Polling to keep state updated (configurable interval)
- Local test harness using Lua 5.4 or newer

## Quickstart

### Prerequisites
- Node.js (for SmartThings CLI)
- SmartThings CLI (`npm install -g @smartthings/cli`)
- Lua 5.4 or newer (for local testing, optional)

### Running Tests

The driver includes a comprehensive test suite that can run locally without SmartThings infrastructure.

#### Test Framework Setup

Ensure `lua5.3` is available and required dependencies are installed:

```bash
# Install Lua 5.3 and LuaRocks
sudo apt-get install lua5.3 lua5.3-dev luarocks

# Install required Lua dependencies
sudo luarocks install luasocket
sudo luarocks install dkjson
sudo luarocks install luaossl
sudo luarocks install cosock
sudo luarocks install lua-log
```

#### Configuration

Tests can be configured in two ways:

1. **Environment Variables** (recommended for CI/automation):
```bash
IP=192.168.1.45 npm run test
```

2. **Test Configuration File** (recommended for local development):
```bash
# Copy and customize the configuration
cp test-config.example.lua test-config.lua
# Edit test-config.lua with your device IP
```

3. **Environment File**:
```bash
# Copy and customize the environment file
cp .env.example .env
# Edit .env with your device IP and test values
```

#### Running Tests

```bash
# Run all tests (unit + integration)
npm run test

# Run only unit tests (no device required)
npm run test:unit

# Run only integration tests (requires real device)
IP=192.168.1.45 npm run test:integration

# Legacy individual device tests
IP=192.168.1.45 npm run test:on
IP=192.168.1.45 npm run test:off
IP=192.168.1.45 npm run test:get
IP=192.168.1.45 LEVEL=50 npm run test:bright
IP=192.168.1.45 HUE=120 SAT=100 VAL=80 npm run test:color
IP=192.168.1.45 RED=255 GREEN=0 BLUE=0 npm run test:rgb
```
#### Install LUA
For local testing, you need **Lua 5.4 or newer**

Install via Homebrew:
```bash
brew install lua
```

Verify the installation:
```bash
lua -v
```

Expected output:
```
Lua 5.4.x  Copyright (C) 1994-2018 Lua.org, PUC-Rio
```

You also need `LuaRocks` and the required libraries (`luasocket`, `luaossl` and `dkjson`) for tests. Install them on macOS with:

```bash
brew install luarocks
luarocks install luasocket
luarocks install dkjson
luarocks install luaossl
luarocks install cosock
luarocks install log
```

### Build & publish
Package the driver:

```bash
npm run build
```

Create a channel (first time):

```bash
npm run channels
```

Enroll your hub and publish (use env vars):

```bash
CHANNEL=<channelId> HUB=<hubId> npm run enroll
DRIVER=<driverId> CHANNEL=<channelId> npm run publish
```

## Debug
Stream logs:

```bash
smartthings edge:drivers:logcat --hub <hubId> --driver <driverId>
```

## License
MIT
