# Roadmap and Twinkly protocol notes

## Current verification status

The Lua tests, diff checks, and local SmartThings package build pass. A temporary localhost HTTP server confirmed that the HTTP client works with real LuaSocket. Direct API calls to a Twinkly TWKP200RGB at `192.168.87.32` (firmware 2.9.1) verified login, token renewal, brightness readback at 1/50/100 percent, two HSV color changes, effect selection, movie selection, and a positive brightness change while off. The original effect, movie selection, brightness and stored color were restored after testing. Its UDP discovery reply contains `OK` where xled-docs lists `yu`; its current effect returns `preset_id`, and its current movie endpoint is `/xled/v1/movies/current`. The driver now handles both observed and documented variants. Automated tests cover duplicate discovery, IP reuse, rapid slider updates, superseded writes, offline rediscovery cooldown, transient scene-list failures, and supported effect filtering. The custom effect capability and presentation are registered in the SmartThings account. Read-only cloud inspection found an Aeotec hub with a Twinkly driver from 2025 and sixteen associated devices, mostly timestamp-based placeholders. Hub-side pairing, SmartThings app state, rapid real slider use, broadcast discovery from the hub and visual LED output remain unverified. No new driver version has been uploaded or assigned to the hub from this workspace.

## First: validate this core on hardware

Install the built driver on a test hub and capture `smartthings edge:drivers:logcat` while testing fresh discovery, repeat scanning, removal and re-addition, IP change, power cycle, and app interference with the auth token. Test on/off, rapid and single dimming changes at 0, 1, 50 and 100 percent, positive level while off, `disabled` brightness, rapid hue/saturation changes, and refresh while commands are in flight. Confirm the observed state on both the LEDs and SmartThings app. Record the selected profile, command latency, and any timeout or duplicate device before expanding the compatibility matrix. A release requires these cases to pass without a stale app state or duplicate device. Direct unicast UDP discovery worked from this Mac, but its broadcast socket was denied by the local OS, so the hub's broadcast path needs its own test.

## Effects and presets

The driver now includes a custom `Effect` list capability. Its fixed labels cover 16 saved movie slots and 15 built-in effects; `supportedValues` comes from the actual movie IDs and effect count on each light. The capability and presentation were registered under `voicetiger23642.twinklyEffect`. Direct API tests confirmed effect and movie selection on firmware 2.9.1, and read-only hardware verification produced seven movie slots and five built-in effects for the current light. Automated tests cover unavailable IDs, deletion, reorder, and uncertain command results. The list still needs a hub/app test, including changes to the Twinkly movie list, firmware variants, persistence across hub reboot, and movie deletion or reorder.

The `Effect N` labels are fixed and identify current slots, not movie names. SmartThings documents `supportedValues` for filtering a list's static alternatives, but does not document per-device alternative labels generated from Twinkly movie names. This is an inference from the documented presentation model, not a verified platform limit. A dynamically named picker remains separate future research. Playlist mode and uploading movies remain separate future work.

## Discovery and migration

Discovery now matches established devices by MAC-based ID and restricts IP matching to timestamp-based legacy placeholders. Duplicate replies and repeated scans while registration is pending request at most one device; a failed registration can be retried after 30 seconds. The one-time re-pair procedure for old placeholders is documented in the README; it requires reassigning SmartThings routines to the replacement device. Broadcast discovery may still fail on VLANs that block broadcasts. SmartThings documents IP preferences on an existing device profile, so that field cannot by itself provide the IP before discovery creates the device. A future manual pairing path must find a supported pre-creation input, verify gestalt, and use the same MAC-based network ID. Do not restore unconditional placeholder creation, which caused the original duplicate-device behavior.

## Sources

- [Twinkly protocol discovery and modes](https://github.com/xled/xled-docs/blob/master/docs/protocol_details.rst)
- [Twinkly REST API endpoints, firmware versions and response codes](https://xled-docs.readthedocs.io/en/latest/rest_api.html)
- [SmartThings LAN Edge driver guidance](https://developer.smartthings.com/docs/devices/hub-connected/lan)
- [SmartThings device preferences](https://developer.smartthings.com/docs/devices/preferences)
- [SmartThings capability presentation display types](https://developer.smartthings.com/docs/devices/capabilities/display-types)
