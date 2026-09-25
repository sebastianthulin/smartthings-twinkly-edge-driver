# Twinkly SmartThings Edge driver

A local LAN driver for Twinkly lights. It supports discovery, on/off, brightness, color, refresh and selecting Twinkly's built-in effects or saved movies.

**[Join the Twinkly Edge SmartThings channel](https://bestow-regional.api.smartthings.com/invite/kVM5OoKdPgl5)** to install the driver on your hub. Source code and issue tracking are on [GitHub](https://github.com/sebastianthulin/smartthings-twinkly-edge-driver).

## Install and add devices

Open the channel invitation above, sign in with your Samsung account, enroll your hub, and install **Twinkly Edge** from the channel's available drivers. Then use **Add device → Scan nearby** while the hub and Twinkly lights are on the same LAN. The driver broadcasts Twinkly's discovery packet, confirms each reply through `/xled/v1/gestalt`, and uses its MAC address as the stable SmartThings network ID. Repeated scans do not request another copy while registration is pending; if registration fails, scanning can retry after 30 seconds. No placeholder is created when no light responds.

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

The device detail view has an **Effect** list. Custom Effect 1–16 correspond to Twinkly's saved movie slots 0–15; Built-in Effect 1–15 correspond to the built-in IDs 0–14. The driver sends `supportedValues` from the light's current `/xled/v1/movies` entries and `/xled/v1/led/effects` count, so unavailable slots are hidden. The list is refreshed on device initialization and each poll (60 seconds by default), or by using Refresh. Its labels identify slots rather than Twinkly movie names, which can be changed in the Twinkly app. If a movie is reordered, its list number changes with its slot; the driver keeps its stable UUID for on/off restoration. The movie API requires firmware 2.5.6 or newer.

A choice is validated against the light again before activation. An unavailable or stale choice leaves its current state unchanged. The custom capability and list presentation are registered under `voicetiger23642.twinklyEffect`; their source is in `integration/`. An existing stored scene remains available for on/off restoration even though the old Scene text preference is no longer shown.

The API has been exercised against a Twinkly TWKP200RGB on firmware 2.9.1: brightness readback matched 1, 50 and 100 percent; color, built-in effects and saved movies selected successfully; and a stale authentication token recovered after another client logged in. The driver is installed on an Aeotec hub. Hub commands selected a built-in effect and a saved movie on the physical light. Fresh pairing on another installation, mobile app rendering, and visual LED output across other models still need community verification. Use `smartthings edge:drivers:logcat` to inspect hub-side failures.

## Contributing

Please report device compatibility issues or feature requests in [GitHub Issues](https://github.com/sebastianthulin/smartthings-twinkly-edge-driver/issues). Include your Twinkly model and firmware version, SmartThings hub model, the steps to reproduce, and relevant Edge driver logs with personal data removed. Code contributions are welcome as [pull requests](https://github.com/sebastianthulin/smartthings-twinkly-edge-driver/pulls). Run `npm test` before submitting a change.

## Development

Run `npm test` for mocked protocol, discovery and command tests. `npm run build` uses the SmartThings CLI to create `.stedge/twinkly-edge.zip` locally. Uploading and assigning a driver version is a separate release step. The custom capability must be accessible to the account that packages the driver.

Protocol and platform references: [Twinkly REST API](https://xled-docs.readthedocs.io/en/latest/rest_api.html), [Twinkly discovery protocol](https://xled-docs.readthedocs.io/en/latest/protocol_details.html), [SmartThings LAN Edge drivers](https://developer.smartthings.com/docs/devices/hub-connected/lan), and [SmartThings list controls](https://developer.smartthings.com/docs/devices/capabilities/display-types).
