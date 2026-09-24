package.loaded["twinkly.scenes"] = nil
local scenes = require "twinkly.scenes"
local snow_uuid = "11111111-1111-1111-1111-111111111111"
local stars_uuid = "22222222-2222-2222-2222-222222222222"
local effect_uuid = "33333333-3333-3333-3333-333333333333"
assert(scenes.parse("demo") == "demo")
local kind, id = scenes.parse("effect:3")
assert(kind == "effect" and id == 3)
kind, id = scenes.parse("movie:15")
assert(kind == "movie" and id == 15)
kind, id = scenes.parse("movie:Snow")
assert(kind == "movie" and id == "Snow")
kind, id = scenes.parse("movie@" .. snow_uuid)
assert(kind == "movie" and id == snow_uuid)
kind, id = scenes.parse("effect@" .. effect_uuid)
assert(kind == "effect" and id == effect_uuid)
for _, invalid in ipairs({ "effect:-1", "movie:", "effect:999", "playlist:0", "" }) do
  assert(scenes.parse(invalid) == nil, invalid)
end

local calls, fail_at = {}, nil
local movies = {
  { id = 2, name = "Snow", unique_id = snow_uuid },
  { id = 7, name = "Stars", unique_id = stars_uuid },
}
local effect_ids = { "", "", "", effect_uuid, "" }
local function call(path, method, payload)
  calls[#calls + 1] = { path = path, method = method, payload = payload }
  if fail_at == #calls then return nil, "timeout" end
  if path == "/xled/v1/led/effects" then
    return { effects_number = 5, unique_ids = effect_ids }
  end
  if path == "/xled/v1/movies" then
    return { movies = movies }
  end
  if path == "/xled/v1/led/effects/current" then
    return { effect_id = 3, unique_id = effect_uuid }
  end
  if path == "/xled/v1/led/movies/current" and method ~= "POST" then
    return { id = 7, name = "Stars", unique_id = stars_uuid }
  end
  return { code = 1000 }
end

assert(scenes.current(call, "demo") == "demo")
assert(scenes.current(call, "effect") == "effect@" .. effect_uuid)
assert(scenes.current(call, "movie") == "movie@" .. stars_uuid)
assert(scenes.current(call, "color") == nil)
calls = {}
local effect_result, effect_canonical = scenes.activate(call, "effect:3")
assert(effect_result and effect_canonical == "effect@" .. effect_uuid)
assert(#calls == 2 and calls[2].path == "/xled/v1/led/mode")
assert(calls[2].payload.mode == "effect" and calls[2].payload.effect_id == 3)
calls = {}
effect_ids[4], effect_ids[2] = effect_ids[2], effect_ids[4]
effect_result, effect_canonical = scenes.activate(call, "effect@" .. effect_uuid)
assert(effect_result and effect_canonical == "effect@" .. effect_uuid and
  calls[2].payload.effect_id == 1, "effect UUID must survive reordering")
effect_ids[4], effect_ids[2] = effect_ids[2], effect_ids[4]
calls = {}
effect_ids[2] = effect_uuid
local duplicate = scenes.activate(call, "effect@" .. effect_uuid)
assert(duplicate == nil and #calls == 1, "duplicate effect UUID must not select an arbitrary effect")
effect_ids[2] = ""
calls = {}
local unavailable, _, reason = scenes.activate(call, "effect:5")
assert(unavailable == nil and reason == "unavailable" and #calls == 1)
calls = {}
local result, canonical = scenes.activate(call, "movie:7")
assert(result and canonical == "movie@" .. stars_uuid)
assert(#calls == 3 and calls[2].payload.id == 7 and calls[3].payload.mode == "movie")
calls = {}
result, canonical = scenes.activate(call, "movie:Snow")
assert(result and canonical == "movie@" .. snow_uuid)
assert(calls[2].payload.id == 2)
calls = {}
movies[1].id = 5
result, canonical = scenes.activate(call, "movie@" .. snow_uuid)
assert(result and canonical == "movie@" .. snow_uuid and calls[2].payload.id == 5,
  "movie identity must survive reordering")
movies[1].id = 2
calls = {}
unavailable, _, reason = scenes.activate(call, "movie:0")
assert(unavailable == nil and reason == "unavailable" and #calls == 1)
calls = {}
assert(scenes.activate(call, "movie:16") == nil and #calls == 0)
calls = {}
fail_at = 2
assert(scenes.activate(call, "movie:7") == nil and #calls == 2,
  "failed selection must not enter movie mode")
calls, fail_at = {}, nil
assert(scenes.activate(call, "demo") and #calls == 1 and calls[1].payload.mode == "demo")
calls, fail_at = {}, 3
local _, err, partial = scenes.activate(call, "movie:Snow")
assert(err == "timeout" and partial == "uncertain" and #calls == 3,
  "mode failure after selecting a movie must be reported as partial")
calls, fail_at = {}, 2
_, err, partial = scenes.activate(call, "movie:Snow")
assert(err == "timeout" and partial == "uncertain" and #calls == 2,
  "a timed-out selection may have changed the active movie")
calls, fail_at = {}, nil
movies[2].name = "Snow"
assert(scenes.activate(call, "movie:Snow") == nil and #calls == 1,
  "duplicate movie names must not select an arbitrary movie")
movies[2].name = "Stars"
calls, fail_at = {}, 1
local unavailable_scene, list_error, failure_kind = scenes.activate(call, "effect:3")
assert(unavailable_scene == nil and list_error == "timeout" and failure_kind == "retry" and
  #calls == 1, "effect list failure must be retryable without changing mode")
calls, fail_at = {}, 1
unavailable_scene, list_error, failure_kind = scenes.activate(call, "movie:Snow")
assert(unavailable_scene == nil and list_error == "timeout" and failure_kind == "retry" and
  #calls == 1, "movie list failure must be retryable without selecting a movie")
