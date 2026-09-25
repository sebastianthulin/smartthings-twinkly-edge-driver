-- Scene selectors are local to a Twinkly device; stable UUIDs are persisted when available.
local M = {}
local MODE = "/xled/v1/led/mode"
local EFFECTS = "/xled/v1/led/effects"
local MOVIES = "/xled/v1/movies"
local MOVIE_CURRENT = "/xled/v1/movies/current"
local LEGACY_MOVIE_CURRENT = "/xled/v1/led/movies/current"

local function movie_current(call, method, payload)
  local result, err = call(MOVIE_CURRENT, method, payload)
  if not result and err == "HTTP 404" then
    return call(LEGACY_MOVIE_CURRENT, method, payload)
  end
  return result, err
end

local function valid_uuid(value)
  return type(value) == "string" and #value == 36 and
    value:match("^%x%x%x%x%x%x%x%x%-%x%x%x%x%-%x%x%x%x%-%x%x%x%x%-%x%x%x%x%x%x%x%x%x%x%x%x$") ~= nil
end

function M.supported_movies(call)
  local available, err = call(MOVIES)
  if not available then return nil, err end
  if type(available.movies) ~= "table" then return nil, "Invalid movies list" end
  local ids, seen = {}, {}
  for _, movie in ipairs(available.movies) do
    local id = type(movie) == "table" and movie.id
    if type(id) ~= "number" or id < 0 or id > 15 or id % 1 ~= 0 or seen[id] then
      return nil, "Invalid movie ID"
    end
    seen[id] = true
    ids[#ids + 1] = id
  end
  table.sort(ids)
  local supported = {}
  for _, id in ipairs(ids) do supported[#supported + 1] = tostring(id) end
  return supported
end

function M.supported_choices(call)
  local movies, movie_err = M.supported_movies(call)
  if not movies and movie_err == "HTTP 404" then movies = {} end
  if not movies then return nil, movie_err end
  local effects, effect_err = call(EFFECTS)
  if not effects then return nil, effect_err end
  local count = effects.effects_number
  if type(count) ~= "number" or count < 0 or count > 15 or count % 1 ~= 0 then
    return nil, "Invalid effects count"
  end
  local choices = {}
  for _, id in ipairs(movies) do choices[#choices + 1] = "movie:" .. id end
  for id = 0, count - 1 do choices[#choices + 1] = "effect:" .. id end
  return choices
end

function M.parse(value)
  if value == "demo" then return "demo" end
  if type(value) ~= "string" then return nil, "Expected demo, effect:N or movie:Name" end
  local kind, digits = value:match("^(effect):(%d+)$")
  if not kind then kind, digits = value:match("^(movie):(%d+)$") end
  if kind then
    local id = tonumber(digits)
    if not id or id > 255 then return nil, "Scene ID is out of range" end
    return kind, id
  end
  local uuid_kind, uuid = value:match("^(effect)@(.+)$")
  if not uuid_kind then uuid_kind, uuid = value:match("^(movie)@(.+)$") end
  if valid_uuid(uuid) then return uuid_kind, uuid, "uuid" end
  local name = value:match("^movie:(.+)$")
  if name and not name:match("^%s*$") then return "movie", name end
  return nil, "Expected demo, effect:N or movie:Name"
end

function M.current(call, mode)
  if mode == "demo" then return "demo" end
  local path, key
  if mode == "effect" then
    path, key = EFFECTS .. "/current", "effect_id"
  elseif mode == "movie" then
    key = "id"
  else
    return nil
  end
  local result
  if mode == "movie" then result = movie_current(call) else result = call(path) end
  local id = result and result[key]
  if mode == "effect" and type(id) ~= "number" then
    id = result and result.preset_id
  end
  if type(id) == "number" and id >= 0 and id % 1 == 0 then
    local choice = mode .. ":" .. id
    if valid_uuid(result.unique_id) then return mode .. "@" .. result.unique_id, choice end
    if mode == "movie" and type(result.name) == "string" and result.name ~= "" and
      not result.name:match("^%d+$") then
      return "movie:" .. result.name, choice
    end
    return choice, choice
  end
  return nil
end

function M.activate(call, value)
  local kind, id, id_type = M.parse(value)
  if not kind then return nil, id, "invalid" end
  if kind == "demo" then
    local result, err = call(MODE, "POST", { mode = "demo" })
    if not result then return nil, err, "uncertain" end
    return result, "demo"
  end
  if kind == "effect" then
    local available, err = call(EFFECTS)
    if not available then return nil, err, "retry" end
    local count = available.effects_number
    if type(count) ~= "number" or count < 0 or count % 1 ~= 0 then
      return nil, "Invalid effects list", "invalid"
    end
    local effect_id = id
    if id_type == "uuid" then
      effect_id = nil
      if type(available.unique_ids) == "table" then
        for index, uuid in ipairs(available.unique_ids) do
          if uuid == id then
            if effect_id then return nil, "Effect UUID is ambiguous", "invalid" end
            effect_id = index - 1
          end
        end
      end
    end
    if not effect_id or effect_id >= count then
      return nil, "Effect " .. id .. " is unavailable", "unavailable"
    end
    local canonical = "effect:" .. effect_id
    local uuid = type(available.unique_ids) == "table" and available.unique_ids[effect_id + 1]
    if valid_uuid(uuid) then canonical = "effect@" .. uuid end
    local result, mode_err = call(MODE, "POST", { mode = "effect", effect_id = effect_id })
    if not result then return nil, mode_err, "uncertain" end
    return result, canonical
  end
  if type(id) == "number" and id > 15 then return nil, "Movie ID must be 0..15", "invalid" end
  local available, err = call(MOVIES)
  if not available then return nil, err, "retry" end
  if type(available.movies) ~= "table" then return nil, "Invalid movies list", "invalid" end
  local found, selected = false, nil
  for _, movie in ipairs(available.movies) do
    local matches = (id_type == "uuid" and movie.unique_id == id) or
      (id_type ~= "uuid" and (movie.id == id or movie.name == id))
    if matches then
      if found then return nil, "Movie name is ambiguous", "invalid" end
      found, selected = true, movie
    end
  end
  if not found then return nil, "Movie " .. id .. " is unavailable", "unavailable" end
  local selected_id = selected.id
  if type(selected_id) ~= "number" or selected_id < 0 or selected_id > 15 or
    selected_id % 1 ~= 0 then return nil, "Invalid movie ID", "invalid" end
  local canonical = "movie:" .. selected_id
  if valid_uuid(selected.unique_id) then canonical = "movie@" .. selected.unique_id end
  local selected, select_err = movie_current(call, "POST", { id = selected_id })
  if not selected then return nil, select_err, "uncertain" end
  local result, mode_err = call(MODE, "POST", { mode = "movie" })
  if not result then return nil, mode_err, "uncertain" end
  return result, canonical
end

return M
