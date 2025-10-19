-- Builtin Effects Feature Implementation
-- Handles built-in Twinkly effects operations

local class = require "vendor.30log"
local AuthenticatedRequestHandler = require "features.shared.authenticated_request_handler"

local BuiltinEffects = class("BuiltinEffects")

function BuiltinEffects:init(http_client, auth_service, logger)
  self._request_handler = AuthenticatedRequestHandler:new(http_client, auth_service, logger)
  self._logger = logger
end

-- List builtin effects
function BuiltinEffects:list_effects(ip)
  local ok, code, status, body = self._request_handler:make_request(ip, "/xled/v1/led/effects", "GET")
  if not ok then
    self._logger:warn("Failed to fetch builtin effects for " .. ip .. ": " .. tostring(status))
    return {}
  end

  local json = require "dkjson"
  local decoded = json.decode(body)
  local list = {}

  if decoded and decoded.unique_ids and type(decoded.unique_ids) == "table" then
    for i, unique_id in ipairs(decoded.unique_ids) do
      table.insert(list, {
        id = i,
        name = "Effect " .. i,
        type = "builtin",
        unique_id = unique_id
      })
    end
  elseif decoded and decoded.effects_number and type(decoded.effects_number) == "number" then
    -- Create effects based on effects_number
    for i = 1, decoded.effects_number do
      table.insert(list, {
        id = i,
        name = "Effect " .. i,
        type = "builtin",
        unique_id = string.format("%08x-%04x-%04x-%04x-%012x", i, 0, 0, 0, i)
      })
    end
  end

  return list
end

-- Set builtin effect
function BuiltinEffects:set_effect(ip, effect_id)
  if not effect_id then
    return nil, "Effect ID is required"
  end
  
  self._logger:debug("Setting builtin effect " .. tostring(effect_id) .. " on " .. tostring(ip))

  local payload = { effect_id = effect_id }
  local ok, code, status, body = self._request_handler:make_request(
    ip, "/xled/v1/led/effects/current", "POST", payload)
  
  if ok then
    return true, body
  else
    return nil, "Failed to set builtin effect: " .. tostring(status)
  end
end

-- Get current builtin effect
function BuiltinEffects:get_current_effect(ip)
  local ok, code, status, body = self._request_handler:make_request(
    ip, "/xled/v1/led/effects/current", "GET")
  
  if ok then
    local json = require "dkjson"
    local decoded = json.decode(body)
    if decoded and decoded.effect_id ~= nil then
      return {
        id = decoded.effect_id,
        unique_id = decoded.unique_id,
        name = "Effect " .. decoded.effect_id,
        type = "builtin"
      }
    end
  else
    self._logger:debug("Failed to get current builtin effect: " .. tostring(status))
  end
  
  return nil
end

return BuiltinEffects
