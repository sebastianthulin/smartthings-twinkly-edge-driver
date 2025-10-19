-- Mode Control Feature Implementation
-- Handles device mode operations (on/off/effect/movie/color)

local class = require "vendor.30log"
local AuthenticatedRequestHandler = require "features.shared.authenticated_request_handler"

local ModeControl = class("ModeControl")

function ModeControl:init(http_client, auth_service, logger)
  self._request_handler = AuthenticatedRequestHandler:new(http_client, auth_service, logger)
  self._logger = logger
end

-- Set device mode (on/off/movie/color/etc)
function ModeControl:set_mode(ip, mode)
  self._logger:debug("Setting mode=" .. tostring(mode) .. " for " .. tostring(ip))
  
  local ok, code, status, body = self._request_handler:make_request(
    ip, "/xled/v1/led/mode", "POST", { mode = mode })
  
  if not ok then 
    return nil, status 
  end
  return true, body
end

-- Get current device mode
function ModeControl:get_mode(ip)
  self._logger:debug("[ModeControl] Getting mode for IP: " .. tostring(ip))
  
  local ok, code, status, body = self._request_handler:make_request(
    ip, "/xled/v1/led/mode", "GET")
  
  if not ok then 
    return nil, "Failed to get mode: " .. tostring(status) .. " Body: " .. (body or "")
  end

  local json = require "dkjson"
  local decoded, _, jerr = json.decode(body)
  if not decoded then
    return nil, "Invalid JSON: " .. tostring(jerr) .. " Body: " .. body
  end

  local raw_mode = decoded.mode
  self._logger:debug("[ModeControl] Raw mode: " .. tostring(raw_mode))
  return raw_mode
end

return ModeControl
