-- User Effects Feature Implementation
-- Handles user-created movie effects operations

local class = require "vendor.30log"
local AuthenticatedRequestHandler = require "features.shared.authenticated_request_handler"

local UserEffects = class("UserEffects")

function UserEffects:init(http_client, auth_service, logger)
  self._request_handler = AuthenticatedRequestHandler:new(http_client, auth_service, logger)
  self._logger = logger
end

-- List user movies/effects
function UserEffects:list_movies(ip)
  local ok, code, status, body = self._request_handler:make_request(ip, "/xled/v1/movies", "GET")
  if not ok then
    self._logger:warn("Failed to fetch user movies for " .. ip .. ": " .. tostring(status))
    return {}
  end

  local json = require "dkjson"
  local decoded = json.decode(body)
  local list = {}

  if decoded and decoded.movies then
    for _, v in ipairs(decoded.movies) do
      v.type = "user"
      table.insert(list, v)
    end
  end

  return list
end

-- Set user movie
function UserEffects:set_movie(ip, movie_id)
  if not movie_id then
    return nil, "Movie ID is required"
  end
  
  self._logger:debug("Setting user movie " .. tostring(movie_id) .. " on " .. tostring(ip))

  local payload = { id = movie_id }
  local ok, code, status, body = self._request_handler:make_request(
    ip, "/xled/v1/led/movies/current", "POST", payload)
  
  if ok then
    return true, body
  else
    return nil, "Failed to set user movie: " .. tostring(status)
  end
end

-- Get current user movie
function UserEffects:get_current_movie(ip)
  local ok, code, status, body = self._request_handler:make_request(
    ip, "/xled/v1/led/movies/current", "GET")
  
  if ok then
    local json = require "dkjson"
    local decoded = json.decode(body)
    if decoded and decoded.id ~= nil then
      return {
        id = decoded.id,
        unique_id = decoded.unique_id,
        name = decoded.name or ("Movie " .. decoded.id),
        type = "user"
      }
    end
  else
    self._logger:debug("Failed to get current user movie: " .. tostring(status))
  end
  
  return nil
end

return UserEffects
