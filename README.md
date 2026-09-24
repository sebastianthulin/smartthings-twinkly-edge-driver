# Twinkly SmartThings Edge driver

A local LAN driver for Twinkly lights. It supports discovery, on/off, brightness, color, refresh and selecting Twinkly's built-in effects or saved movies. See [ROADMAP.md](ROADMAP.md) for remaining work.

## Install and add devices

Install the driver on a SmartThings hub, then use **Add device → Scan nearby** while the hub and Twinkly lights are on the same LAN. The driver broadcasts Twinkly's discovery packet, confirms each reply through `/xled/v1/gestalt`, and uses its MAC address as the stable SmartThings network ID. Repeated scans do not request another copy while registration is pending; if registration fails, scanning can retry after 30 seconds. No placeholder is created when no light responds.

The hub must be able to send UDP broadcast to port 5555 and reach the lights on TCP port 80. If the network blocks broadcast between the hub and lights, discovery cannot add them. An existing manually configured placeholder device can still use its IP address preference; this is kept for migration, not for creating new devices.

To replace an old timestamp-based placeholder with a stable MAC-based device, first note any SmartThings routines using it. Remove the placeholder, then run **Add device → Scan nearby** with the light powered and on the same LAN as the hub. The replacement is a new SmartThings device, so reassign those routines. If scanning finds nothing, check UDP broadcast between the hub and light; setting an IP on the deleted placeholder cannot create a new device. Existing MAC-based devices are matched only by MAC, so DHCP reusing their former IP cannot silently merge two different lights.

Discovery reads the firmware version and selects a switch, dimmer, or color profile based on the APIs documented for that version. An unknown version gets the switch profile until it is re-paired after the version can be read.
The IP address preference also provides a manual override for discovered devices. Leave it at `0.0.0.0` to let discovery update the address when DHCP changes it. Changing a manual address back to `0.0.0.0` clears that address; polling continues to search for the device by its MAC-based ID.

## Behavior

- On restores the last known effect or movie, demo, or static color; it starts demo mode when none is known.
- Off switches off directly; the last supported mode is recorded during refresh and successful mode changes.
- Brightness uses Twinkly's 0–100 percent absolute dimmer API. A SmartThings level above zero turns an off light on before applying the level; level 0 turns it off and retains the last nonzero brightness for the next on command. The first brightness change is sent immediately; rapid follow-up values are combined and sent at most once every 120 ms. If Twinkly reports dimming disabled, SmartThings shows 100 percent because the LEDs run at full brightness.
- Color uses the firmware's `/led/color` API, available from version 2.7.1. SetColor, SetHue and SetSaturation are supported on devices with the color profile. The first color change is sent immediately; rapid follow-up values are combined and sent at most once every 150 ms. Each color update makes at most one color write and one mode write.
- Refresh and a periodic poll update switch, brightness and, in color mode, hue/saturation. Polling defaults to 60 seconds and is configurable from 30 to 3600 seconds. When a device is offline, rediscovery runs at most once every 30 seconds; a manual IP override skips broadcast rediscovery.
- Commands report new state only after a successful Twinkly response. HTTP sockets have a 3-second idle timeout, a complete authenticated command has an 8-second network budget, and responses are limited to 256 KiB. Authentication is cached and renewed once after HTTP 401.

## Scenes and presets

Open the device's **Settings → Scene** field in SmartThings. Enter one of these values and save:

- `demo` cycles through the built-in effects.
- `effect:0` plays built-in effect 0; replace 0 with another available numeric ID.
- `movie:Snow` plays a saved movie by its exact name in the Twinkly app. `movie:2` also works when its numeric ID is known.

The driver reads the device's effect count or movie list before selecting a scene. An unavailable or ambiguous value entered in Settings leaves the current light state unchanged. If the light is temporarily unreachable, the choice is retained and retried after a successful refresh or on command. An explicit Off or color command cancels that pending choice. Twinkly's effects API exposes IDs but no names; movie names must match exactly and be unique. The driver remembers each effect's or movie's `unique_id` when available, so reordering does not change which one on/off restores. If a previously saved scene is deleted, **On** starts demo mode. A color command supersedes the current scene. The `movie` API requires firmware 2.5.6 or newer.

SmartThings device Settings is the working scene control in this release. A named picker in the device detail view would require a registered custom capability and presentation in the owner's SmartThings account; that work is tracked in [ROADMAP.md](ROADMAP.md).

Devices and firmware differ. This code has automated tests with mocked transport but has not been validated against a physical Twinkly or SmartThings hub in this workspace. Use `smartthings edge:drivers:logcat` to inspect hardware failures.

## Development

Run `npm test` for mocked protocol, discovery and command tests. `npm run build` uses the SmartThings CLI to create `.stedge/twinkly-edge.zip` locally. Uploading and assigning a driver version is a separate release step.
