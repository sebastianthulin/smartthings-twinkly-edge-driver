# Roadmap and Twinkly protocol notes

## Current verification status

The Lua tests, diff checks, and local SmartThings package build pass. A temporary localhost HTTP server also confirmed that the HTTP client works with real LuaSocket for login, verification and a command. Discovery tests cover IP reuse, duplicate replies, repeated scans while creation is pending, retry after failed creation, and old timestamp-based placeholders. Color and dimmer tests cover rapid slider updates, superseded writes, and cancellation by Off. The HTTP client now bounds the whole authenticated command to eight seconds, and repeated offline refreshes share a 30-second rediscovery cooldown. Scene tests cover transient effect/movie list failures without a write. Physical light output, hub-side pairing, and the SmartThings app UI still require an online Twinkly and hub. The most recent direct, read-only gestalt probe to the configured IP returned `No route to host` even with LAN access enabled. No driver version has been uploaded or assigned to a hub from this workspace.

## First: validate this core on hardware

First make `/xled/v1/gestalt` reachable from the hub's LAN; the configured IP currently has no route from this workspace. Then install the built driver on a test hub and capture `smartthings edge:drivers:logcat` while testing fresh discovery, repeat scanning, removal and re-addition, IP change, power cycle, and app interference with the auth token. Test on/off, rapid and single dimming changes at 0, 1, 50 and 100 percent, positive level while off, `disabled` brightness, rapid hue/saturation changes, and refresh while commands are in flight. Confirm the observed state on both the LEDs and SmartThings app. Record device model, firmware, profile, command latency, and any timeout or duplicate device before expanding the compatibility matrix. A release requires all these cases to pass without a stale app state or duplicate device.

## Effects and presets

The driver now selects `demo`, numbered built-in effects, and saved movies by name or ID through a SmartThings Settings field. It validates effect IDs using `/xled/v1/led/effects` and movie entries using `/xled/v1/movies`, uses the documented selection endpoints, and remembers effect and movie UUIDs across restart when the firmware provides them. Automated tests cover unavailable IDs, deletion, reorder, and uncertain command results. Validate these flows on physical devices, including app interference, firmware variants, persistence across hub reboot, and movie deletion or reorder.

The proposed named selector needs another design pass. SmartThings documents a `list` presentation with static labels and a `supportedValues` attribute for filtering choices, but this does not establish a way to display arbitrary per-device movie names that change in the Twinkly app. This is an inference from the documented presentation model, not a verified platform limit. Keep the working Settings field until a test capability proves that dynamic movie labels can be displayed and refreshed. Registering that capability and presentation also requires the target account's namespace. Do not bind an unregistered capability into a shipping profile. Playlist mode and uploading movies remain separate future work.

## Discovery and migration

Discovery now matches established devices by MAC-based ID and restricts IP matching to timestamp-based legacy placeholders. Duplicate replies and repeated scans while registration is pending request at most one device; a failed registration can be retried after 30 seconds. The one-time re-pair procedure for old placeholders is documented in the README; it requires reassigning SmartThings routines to the replacement device. Broadcast discovery may still fail on VLANs that block broadcasts. SmartThings documents IP preferences on an existing device profile, so that field cannot by itself provide the IP before discovery creates the device. A future manual pairing path must find a supported pre-creation input, verify gestalt, and use the same MAC-based network ID. Do not restore unconditional placeholder creation, which caused the original duplicate-device behavior.

## Sources

- [Twinkly protocol discovery and modes](https://github.com/xled/xled-docs/blob/master/docs/protocol_details.rst)
- [Twinkly REST API endpoints, firmware versions and response codes](https://xled-docs.readthedocs.io/en/latest/rest_api.html)
- [SmartThings LAN Edge driver guidance](https://developer.smartthings.com/docs/devices/hub-connected/lan)
- [SmartThings device preferences](https://developer.smartthings.com/docs/devices/preferences)
- [SmartThings capability presentation display types](https://developer.smartthings.com/docs/devices/capabilities/display-types)
