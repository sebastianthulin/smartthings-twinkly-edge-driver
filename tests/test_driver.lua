package.loaded["st.driver"] = nil
package.loaded["st.capabilities"] = nil
package.loaded["twinkly.api"] = nil
package.loaded["twinkly.discovery"] = nil
package.loaded["log"] = { warn = function() end }
local template
package.loaded["st.driver"] = function(_, definition)
  template = definition
  return { run = function() end }
end
local function attr(value) return { value = value } end
local caps = {
  switch = { ID = "switch", switch = { NAME = "switch",
    on = function() return attr("on") end, off = function() return attr("off") end },
    commands = { on = { NAME = "on" }, off = { NAME = "off" } } },
  switchLevel = { ID = "switchLevel", level = attr, commands = { setLevel = { NAME = "setLevel" } } },
  colorControl = { ID = "colorControl", hue = { NAME = "hue" }, saturation = { NAME = "saturation" },
    commands = { setColor = { NAME = "setColor" }, setHue = { NAME = "setHue" },
      setSaturation = { NAME = "setSaturation" } } },
  refresh = { ID = "refresh", commands = { refresh = { NAME = "refresh" } } },
  ["voicetiger23642.twinklyEffect"] = {
    ID = "voicetiger23642.twinklyEffect",
    selectedEffect = function(value) return { value = value, selector = "selected" } end,
    supportedEffects = function(value) return { value = value, selector = "supported" } end,
    commands = { setEffect = { NAME = "setEffect" } },
  },
}
package.loaded["st.capabilities"] = caps
setmetatable(caps.colorControl.hue, { __call = function(_, value) return attr(value) end })
setmetatable(caps.colorControl.saturation, { __call = function(_, value) return attr(value) end })
local calls, fail = {}, false
local movie_uuid = "11111111-1111-1111-1111-111111111111"
local fail_movie_mode = false
local movie_exists = true
local fail_current_movie = false
local mode_value = "movie"
local color_response
local fields
local rediscover = false
local scans = 0
local brightness_disabled = false
local brightness_missing = false
local during_color_write
package.loaded["twinkly.api"] = {
  call = function(ip, path, method, payload)
    calls[#calls + 1] = { path = path, method = method, payload = payload }
    if path == "/xled/v1/led/color" and method == "POST" and during_color_write then
      local callback = during_color_write
      during_color_write = nil
      callback()
    end
    if fail or ip == "192.168.1.99" then return nil, "timeout" end
    if fail_movie_mode and path == "/xled/v1/led/mode" and method == "POST" and
      payload.mode == "movie" then return nil, "timeout" end
    if fail_current_movie and path == "/xled/v1/movies/current" and method ~= "POST" then
      return nil, "timeout"
    end
    if path:find("mode") and method ~= "POST" then return { mode = mode_value } end
    if path == "/xled/v1/led/effects" then return { effects_number = 5 } end
    if path == "/xled/v1/movies" then
      return { movies = movie_exists and { { id = 2, name = "Snow", unique_id = movie_uuid } } or {} }
    end
    if path == "/xled/v1/movies/current" and method ~= "POST" then
      return { id = 2, name = "Snow", unique_id = movie_uuid }
    end
    if path:find("brightness") and method ~= "POST" then
      local value = 42
      if brightness_missing then value = nil end
      return { value = value, mode = brightness_disabled and "disabled" or "enabled" }
    end
    if path == "/xled/v1/led/color" and method ~= "POST" then
      return color_response or { code = 1000 }
    end
    return { code = 1000 }
  end,
  clear = function() end,
}
package.loaded["twinkly.discovery"] = {
  scan = function(_, create)
    scans = scans + 1
    if rediscover and create == false then fields.ipAddress = "192.168.1.2" end
    return true
  end,
  pending_ip = function() return "192.168.1.2" end,
}
require "init"
assert(template.lifecycle_handlers.added == nil, "SmartThings invokes init after added")
local events = {}
local effect_events = {}
local switch_state
fields = {}
local device = {
  id = "dev", device_network_id = "twinkly-aabbccddeeff", profile = { name = "twinkly-color-light" },
  get_field = function(_, key) return fields[key] end,
  set_field = function(_, key, value) fields[key] = value end,
  emit_event = function(_, event)
    if event.selector then effect_events[#effect_events + 1] = event; return end
    events[#events + 1] = event.value
    if event.value == "on" or event.value == "off" then switch_state = event.value end
  end,
  get_latest_state = function(_, _, _, name)
    if name == "switch" then return switch_state end
    if name == "hue" then return 25 end
    if name == "saturation" then return 80 end
  end,
}
local scheduled, cancelled = 0, 0
local color_timers, level_timers = {}, {}
local function run_color_timer()
  local timer = fields.color_timer
  assert(timer and not timer.cancelled, "expected an active color timer")
  timer.callback()
end
local function run_level_timer()
  local timer = fields.level_timer
  assert(timer and not timer.cancelled, "expected an active level timer")
  timer.callback()
end
local driver = {
  call_on_schedule = function(_, interval)
    assert(interval == 60)
    scheduled = scheduled + 1
    return scheduled
  end,
  call_with_delay = function(_, delay, callback)
    local timer = { callback = callback }
    if delay == 0.15 then
      color_timers[#color_timers + 1] = timer
    elseif delay == 0.12 then
      level_timers[#level_timers + 1] = timer
    else
      error("unexpected delay: " .. tostring(delay))
    end
    return timer
  end,
  cancel_timer = function(_, timer)
    if type(timer) == "table" then timer.cancelled = true else cancelled = cancelled + 1 end
  end,
}
template.lifecycle_handlers.init(driver, device)
assert(fields.ipAddress == "192.168.1.2")
assert(events[1] == "on" and events[2] == 42)
assert(scheduled == 1)
assert(effect_events[1].selector == "supported" and
  effect_events[1].value[1] == "movie:2" and
  effect_events[1].value[2] == "effect:0" and
  effect_events[1].value[6] == "effect:4" and
  effect_events[2].selector == "selected" and effect_events[2].value == "movie:2",
  "the selector must publish current movie slots and built-in effects")
local effect_events_before_refresh = #effect_events
template.capability_handlers.refresh.refresh(driver, device)
assert(#effect_events == effect_events_before_refresh,
  "unchanged supported values must not be emitted on every poll")
local before = #events
fail = true
local calls_before = #calls
template.capability_handlers.switch.on(driver, device)
assert(#events == before, "failed command must not emit")
assert(#calls == calls_before + 1, "network error must not trigger a second mode request")
fail = false
template.capability_handlers.switch.on(driver, device)
assert(events[#events] == "on")
calls_before = #calls
template.capability_handlers.switch.off(driver, device)
assert(#calls == calls_before + 1 and calls[#calls].payload.mode == "off")
template.lifecycle_handlers.infoChanged(driver, device, nil,
  { old_st_store = { preferences = {} } })
assert(scheduled == 1, "unrelated metadata changes must not restart polling")
device.preferences = { pollInterval = 120 }
driver.call_on_schedule = function(_, interval)
  assert(interval == 120)
  scheduled = scheduled + 1
  return scheduled
end
template.lifecycle_handlers.infoChanged(driver, device, nil,
  { old_st_store = { preferences = {} } })
assert(scheduled == 2 and cancelled == 1)
local scans_before_failures = scans
fail = true
template.capability_handlers.refresh.refresh(driver, device)
template.capability_handlers.refresh.refresh(driver, device)
assert(scans == scans_before_failures + 1,
  "repeated offline refreshes must share one rediscovery attempt")
fields.last_rediscovery = os.time() - 31
template.capability_handlers.refresh.refresh(driver, device)
assert(scans == scans_before_failures + 2,
  "rediscovery must retry after the cooldown")
fail = false
fields.last_rediscovery = nil
fields.ipAddress = "192.168.1.99"
rediscover = true
template.capability_handlers.refresh.refresh(driver, device)
assert(fields.ipAddress == "192.168.1.2" and events[#events - 1] == "on")
rediscover = false
brightness_disabled = true
template.capability_handlers.refresh.refresh(driver, device)
assert(events[#events] == 100, "disabled dimmer must report full brightness")
brightness_missing = true
template.capability_handlers.refresh.refresh(driver, device)
assert(events[#events] == 100, "disabled dimmer needs no valid stored value")
brightness_missing = false
brightness_disabled = false
brightness_missing = true
local before_invalid_brightness = #events
template.capability_handlers.refresh.refresh(driver, device)
assert(#events == before_invalid_brightness + 1 and events[#events] == "on",
  "enabled dimmer without a valid value must not invent a level")
brightness_missing = false
template.capability_handlers.switchLevel.setLevel(driver, device, { args = { level = 60 } })
assert(events[#events] == 60)
local sent = calls[#calls].payload
assert(sent.value == 60 and sent.mode == "enabled")
template.capability_handlers.switch.off(driver, device)
local calls_before_level = #calls
template.capability_handlers.switchLevel.setLevel(driver, device, { args = { level = 40 } })
assert(calls[calls_before_level + 1].path == "/xled/v1/movies" and
  calls[#calls].path == "/xled/v1/led/out/brightness")
assert(switch_state == "on" and events[#events] == 40,
  "positive level must turn an off light on")
local calls_before_zero = #calls
template.capability_handlers.switchLevel.setLevel(driver, device, { args = { level = 0 } })
assert(#calls == calls_before_zero + 1 and calls[#calls].payload.mode == "off")
assert(switch_state == "off" and events[#events] == "off",
  "zero level must turn off without saving zero brightness")
local count_before_failed_on = #calls
local events_before_failed_on = #events
fail = true
template.capability_handlers.switchLevel.setLevel(driver, device, { args = { level = 75 } })
assert(#calls == count_before_failed_on + 1 and #events == events_before_failed_on,
  "failed power-on must not claim a new brightness")
fail = false
template.capability_handlers.switchLevel.setLevel(driver, device, { args = { level = 101 } })
assert(switch_state == "on" and events[#events] == 100 and calls[#calls].payload.value == 100)
local events_before_failed_dim = #events
fail = true
template.capability_handlers.switchLevel.setLevel(driver, device, { args = { level = 25 } })
run_level_timer()
assert(#events == events_before_failed_dim, "failed brightness write must not emit level")
fail = false
template.capability_handlers.switchLevel.setLevel(driver, device, { args = { level = 35.6 } })
run_level_timer()
assert(events[#events] == 36 and calls[#calls].payload.value == 36)
local events_before_bad = #events
template.capability_handlers.switchLevel.setLevel(driver, device, { args = { level = "bad" } })
assert(#events == events_before_bad)
template.capability_handlers.switchLevel.setLevel(driver, device, { args = { level = math.huge } })
assert(#events == events_before_bad)
run_level_timer()
local calls_before_slider = #calls
template.capability_handlers.switchLevel.setLevel(driver, device, { args = { level = 10 } })
for value = 11, 100 do
  template.capability_handlers.switchLevel.setLevel(driver, device, { args = { level = value } })
end
assert(#calls == calls_before_slider + 1 and calls[#calls].payload.value == 10,
  "first brightness value must be sent immediately")
run_level_timer()
assert(#calls == calls_before_slider + 2 and calls[#calls].payload.value == 100,
  "rapid brightness updates must send only the latest trailing value")
template.capability_handlers.switchLevel.setLevel(driver, device, { args = { level = 50 } })
local cancelled_level = fields.level_timer
local events_before_queued_level_poll = #events
template.capability_handlers.refresh.refresh(driver, device)
assert(#events == events_before_queued_level_poll + 1,
  "polling must not report stale brightness while a newer level is queued")
local calls_before_level_off = #calls
template.capability_handlers.switch.off(driver, device)
assert(cancelled_level.cancelled and #calls == calls_before_level_off + 1 and
  calls[#calls].payload.mode == "off", "Off must cancel a queued brightness update")
template.capability_handlers.switch.on(driver, device)
local calls_before_color = #calls
for hue = 1, 100 do
  template.capability_handlers.colorControl.setColor(driver, device,
    { args = { color = { hue = hue, saturation = 100 } } })
end
assert(#calls == calls_before_color + 2,
  "first color must be visible immediately while later slider updates are queued")
template.capability_handlers.colorControl.setHue(driver, device, { args = { hue = 60 } })
template.capability_handlers.colorControl.setSaturation(driver, device, { args = { saturation = 30 } })
mode_value = "color"
color_response = { hue = 0, saturation = 0 }
local events_before_queued_color_poll = #events
template.capability_handlers.refresh.refresh(driver, device)
assert(#events == events_before_queued_color_poll + 2 and
  fields.desired_color.hue == 60 and fields.desired_color.saturation == 30,
  "polling must not overwrite a queued color with stale device values")
color_response = nil
mode_value = "movie"
local calls_before_trailing_color = #calls
run_color_timer()
assert(#calls == calls_before_trailing_color + 2 and calls[#calls - 1].payload.hue == 216 and
  calls[#calls - 1].payload.saturation == 77 and events[#events] == "on",
  "rapid color changes must combine into one trailing color and mode request")
run_color_timer()
local before_reentrant = #calls
local events_before_reentrant = #events
during_color_write = function()
  template.capability_handlers.colorControl.setHue(driver, device, { args = { hue = 80 } })
  template.capability_handlers.colorControl.setSaturation(driver, device,
    { args = { saturation = 20 } })
end
template.capability_handlers.colorControl.setColor(driver, device,
  { args = { color = { hue = 10, saturation = 10 } } })
assert(#calls == before_reentrant + 1 and #events == events_before_reentrant,
  "a superseded in-flight color must not send a mode write or stale events")
run_color_timer()
assert(#calls == before_reentrant + 3 and calls[#calls - 1].payload.hue == 288 and
  calls[#calls - 1].payload.saturation == 51,
  "in-flight hue and saturation changes must retain both latest values")
template.capability_handlers.colorControl.setColor(driver, device,
  { args = { color = { hue = 100, saturation = 100 } } })
run_color_timer()
assert(calls[#calls - 1].payload.hue == 359, "Twinkly hue must be 0..359")
local calls_before_invalid_color = #calls
template.capability_handlers.colorControl.setColor(driver, device,
  { args = { color = { hue = math.huge, saturation = 50 } } })
template.capability_handlers.colorControl.setColor(driver, device,
  { args = { color = "invalid" } })
assert(#calls == calls_before_invalid_color, "malformed color must not reach HTTP")
mode_value = "color"
color_response = { hue = math.huge, saturation = 255 }
local events_before_invalid_color = #events
template.capability_handlers.refresh.refresh(driver, device)
assert(#events == events_before_invalid_color + 2 and events[#events] == 42,
  "non-finite color response must not emit color events")
color_response = nil
mode_value = "movie"
device.preferences.scene = "effect:2"
template.lifecycle_handlers.infoChanged(driver, device, nil,
  { old_st_store = { preferences = { pollInterval = 120 } } })
assert(calls[#calls].payload.mode == "effect" and calls[#calls].payload.effect_id == 2)
assert(fields.last_scene == "effect:2" and scheduled == 2)
template.capability_handlers.switch.off(driver, device)
template.capability_handlers.switch.on(driver, device)
assert(calls[#calls].payload.mode == "effect" and calls[#calls].payload.effect_id == 2)
local event_count = #events
local call_count = #calls
device.preferences.scene = "movie:3"
template.lifecycle_handlers.infoChanged(driver, device, nil,
  { old_st_store = { preferences = { pollInterval = 120, scene = "effect:2" } } })
assert(#calls == call_count + 1 and #events == event_count,
  "unavailable movie must not change state")
assert(fields.last_scene == "effect:2")
device.preferences.scene = "movie:2"
template.lifecycle_handlers.infoChanged(driver, device, nil,
  { old_st_store = { preferences = { pollInterval = 120, scene = "movie:3" } } })
assert(calls[#calls - 1].path == "/xled/v1/movies/current")
assert(calls[#calls].payload.mode == "movie" and fields.last_scene == "movie@" .. movie_uuid)
template.capability_handlers["voicetiger23642.twinklyEffect"].setEffect(driver, device,
  { args = { effect = "movie:2" } })
assert(calls[#calls - 1].path == "/xled/v1/movies/current" and
  calls[#calls - 1].payload.id == 2 and calls[#calls].payload.mode == "movie" and
  effect_events[#effect_events].value == "movie:2",
  "selecting a visible custom effect must activate its current slot")
local calls_before_invalid_choice = #calls
template.capability_handlers["voicetiger23642.twinklyEffect"].setEffect(driver, device,
  { args = { effect = "movie:99" } })
assert(#calls == calls_before_invalid_choice,
  "a stale or invalid choice must not be sent to the light")
device.preferences.scene = "movie@" .. movie_uuid
template.lifecycle_handlers.infoChanged(driver, device, nil,
  { old_st_store = { preferences = { pollInterval = 120, scene = "movie:2" } } })
assert(calls[#calls - 1].path == "/xled/v1/movies/current" and
  calls[#calls - 1].payload.id == 2 and calls[#calls].payload.mode == "movie",
  "a UUID scene selection must resolve the movie's current slot")
fail_current_movie = true
template.capability_handlers.refresh.refresh(driver, device)
assert(fields.last_scene == "movie@" .. movie_uuid,
  "transient current-movie read failure must not erase the remembered scene")
fail_current_movie = false
device.preferences.scene = "movie:Snow"
fail_movie_mode = true
template.lifecycle_handlers.infoChanged(driver, device, nil,
  { old_st_store = { preferences = { pollInterval = 120, scene = "movie@" .. movie_uuid } } })
assert(fields.last_scene == "movie@" .. movie_uuid and calls[#calls].path == "/xled/v1/led/out/brightness",
  "partial movie change must refresh actual state")
fail_movie_mode = false
movie_exists = false
template.capability_handlers.switch.on(driver, device)
assert(fields.last_scene == "demo" and calls[#calls].payload.mode == "demo",
  "deleted saved movie must fall back to demo on switch-on")
template.capability_handlers.refresh.refresh(driver, device)
local filtered = effect_events[#effect_events]
assert(filtered.selector == "supported" and #filtered.value == 5 and
  filtered.value[1] == "effect:0" and filtered.value[5] == "effect:4",
  "removed movies must disappear from the supported list")
device.preferences.ipAddress = "192.168.1.50"
template.lifecycle_handlers.infoChanged(driver, device, nil,
  { old_st_store = { preferences = { pollInterval = 120, scene = "movie:Snow" } } })
assert(fields.ipAddress == "192.168.1.50")
local scans_before_manual = scans
fail = true
template.capability_handlers.refresh.refresh(driver, device)
assert(scans == scans_before_manual,
  "a manual IP override must not trigger an ineffective broadcast scan")
fail = false
device.preferences.ipAddress = "0.0.0.0"
template.lifecycle_handlers.infoChanged(driver, device, nil,
  { old_st_store = { preferences = { pollInterval = 120, scene = "movie:Snow",
    ipAddress = "192.168.1.50" } } })
assert(fields.ipAddress == nil and fields.poll_timer ~= nil,
  "clearing manual IP must clear the stale address and keep rediscovery scheduled")
rediscover = true
fields.last_rediscovery = os.time() - 31
template.capability_handlers.refresh.refresh(driver, device)
assert(fields.ipAddress == "192.168.1.2", "automatic discovery must recover the IP")
driver.call_on_schedule = function(_, interval)
  assert(interval == 60, "invalid polling interval must use the default")
  scheduled = scheduled + 1
  return scheduled
end
device.preferences.pollInterval = math.huge
template.lifecycle_handlers.infoChanged(driver, device, nil,
  { old_st_store = { preferences = { pollInterval = 120, scene = "movie:Snow",
    ipAddress = "0.0.0.0" } } })
fail = true
device.preferences.scene = "effect:1"
template.lifecycle_handlers.infoChanged(driver, device, nil,
  { old_st_store = { preferences = { pollInterval = math.huge, scene = "movie:Snow",
    ipAddress = "0.0.0.0" } } })
assert(fields.pending_scene == "effect:1", "offline scene choice must be retained")
fail = false
template.capability_handlers.refresh.refresh(driver, device)
assert(fields.pending_scene == nil and fields.last_scene == "effect:1" and
  calls[#calls].payload.effect_id == 1,
  "pending scene must apply after connectivity returns")
fail = true
device.preferences.scene = "effect:2"
template.lifecycle_handlers.infoChanged(driver, device, nil,
  { old_st_store = { preferences = { pollInterval = math.huge, scene = "effect:1",
    ipAddress = "0.0.0.0" } } })
fail = false
template.capability_handlers.switch.on(driver, device)
assert(fields.pending_scene == nil and fields.last_scene == "effect:2" and
  calls[#calls].payload.effect_id == 2,
  "switch-on must apply a pending scene before restoring an older one")
local calls_before_invalid_scene = #calls
device.preferences.scene = "bad"
template.lifecycle_handlers.infoChanged(driver, device, nil,
  { old_st_store = { preferences = { pollInterval = math.huge, scene = "effect:2",
    ipAddress = "0.0.0.0" } } })
assert(fields.pending_scene == nil and #calls == calls_before_invalid_scene,
  "invalid scene must not retry indefinitely")
fail = true
device.preferences.scene = "effect:3"
template.lifecycle_handlers.infoChanged(driver, device, nil,
  { old_st_store = { preferences = { pollInterval = math.huge, scene = "bad",
    ipAddress = "0.0.0.0" } } })
assert(fields.pending_scene == "effect:3")
template.capability_handlers.switch.off(driver, device)
assert(fields.pending_scene == nil, "an explicit off command cancels a pending scene")
fail = false
template.capability_handlers.refresh.refresh(driver, device)
assert(fields.pending_scene == nil and calls[#calls].path == "/xled/v1/led/out/brightness")
fail = true
device.preferences.scene = "effect:4"
template.lifecycle_handlers.infoChanged(driver, device, nil,
  { old_st_store = { preferences = { pollInterval = math.huge, scene = "effect:3",
    ipAddress = "0.0.0.0" } } })
assert(fields.pending_scene == "effect:4")
fail = false
template.capability_handlers.colorControl.setColor(driver, device,
  { args = { color = { hue = 20, saturation = 40 } } })
assert(fields.pending_scene == nil and fields.last_scene == nil,
  "explicit color command must supersede a pending scene")
local calls_before_cancelled_color = #calls
template.capability_handlers.colorControl.setColor(driver, device,
  { args = { color = { hue = 10, saturation = 20 } } })
local cancelled_color = fields.color_timer
template.capability_handlers.switch.off(driver, device)
assert(cancelled_color.cancelled and #calls == calls_before_cancelled_color + 1,
  "Off must cancel a queued color without writing it")
local events_before_failed_color = #events
fail = true
template.capability_handlers.colorControl.setColor(driver, device,
  { args = { color = { hue = 30, saturation = 40 } } })
assert(#events == events_before_failed_color, "failed color write must not emit color state")
assert(fields.desired_color == nil, "a failed color write must discard its unconfirmed target")
fail = false
template.lifecycle_handlers.removed(driver, device)
assert(cancelled == scheduled and fields.poll_timer == nil)
