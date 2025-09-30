# Twinkly Edge Driver
This repository contains a SmartThings Edge driver for controlling Twinkly lights over the local LAN.

Channel Link: https://callaway.smartthings.com/channels/912e7705-ec88-413c-a3ac-1c5ecd9015ba

## Compability
This driver is only tested on the following products: 
- TWKP200RGB-G [Twinkly Candies / Pearl]

## Features
- Auto-discovery via Twinkly UDP broadcasts (port 5555)
- Switch capability (on = movie mode, off = off)
- Polling to keep state updated (configurable interval)
- Local test harness using Lua 5.4 or newer

## Quickstart

### Prerequisites
- Node.js (for SmartThings CLI)
- SmartThings CLI (`npm install -g @smartthings/cli`)
- Lua 5.4 or newer (for local testing, optional)

### Local tests
Ensure `lua` is available, then run:

```bash
IP=192.168.1.45 npm run test:on
IP=192.168.1.45 npm run test:off
IP=192.168.1.45 npm run test:get
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
