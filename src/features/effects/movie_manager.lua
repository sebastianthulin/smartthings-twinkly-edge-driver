-- Movie Manager Feature Implementation
-- Handles device movies (default states, not effects)

local class = require "vendor.30log"
local AuthenticatedRequestHandler = require "features.shared.authenticated_request_handler"

local MovieManager = class("MovieManager")

function MovieManager:init(http_client, auth_service, logger)
  self._request_handler = AuthenticatedRequestHandler:new(http_client, auth_service, logger)
  self._logger = logger
end

-- List movies available on device
function MovieManager:list_movies(ip)
  local ok, code, status, body = self._request_handler:make_request(ip, "/xled/v1/movies", "GET")
  if not ok then
    self._logger:warn("Failed to fetch movies for " .. ip .. ": " .. tostring(status))
    return {}
  end

  local json = require "dkjson"
  local decoded = json.decode(body)
  local list = {}

  if decoded and decoded.movies then
    for _, movie in ipairs(decoded.movies) do
      table.insert(list, {
        id = movie.id,
        name = movie.name,
        unique_id = movie.unique_id,
        descriptor_type = movie.descriptor_type,
        leds_per_frame = movie.leds_per_frame,
        frames_number = movie.frames_number,
        fps = movie.fps
      })
    end
  end

  return list
end

-- Set movie on device (sets device to movie mode)
function MovieManager:set_movie(ip, movie_id)
  if not movie_id then
    return nil, "Movie ID is required"
  end
  
  self._logger:debug("Setting movie " .. tostring(movie_id) .. " on " .. tostring(ip))

  local payload = { id = movie_id }
  local ok, code, status, body = self._request_handler:make_request(
    ip, "/xled/v1/led/movies/current", "POST", payload)
  
  if ok then
    return true, body
  else
    return nil, "Failed to set movie: " .. tostring(status)
  end
end

-- Get current movie from device
function MovieManager:get_current_movie(ip)
  local ok, code, status, body = self._request_handler:make_request(
    ip, "/xled/v1/led/movies/current", "GET")
  
  if ok then
    local json = require "dkjson"
    local decoded = json.decode(body)
    if decoded and decoded.id ~= nil then
      return {
        id = decoded.id,
        unique_id = decoded.unique_id,
        name = decoded.name or ("Movie " .. decoded.id)
      }
    end
  else
    self._logger:debug("Failed to get current movie: " .. tostring(status))
  end
  
  return nil
end

return MovieManager
