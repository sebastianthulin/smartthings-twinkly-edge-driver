local cosock = require "cosock"
local http = cosock.asyncify("socket.http")
local ltn12 = require "ltn12"
local json = require "dkjson"
local login = require "twinkly.login"
local log = require "log"

local mode = {}

function mode.get_mode(ip)
  log.debug("[get_mode] Entering with IP: " .. tostring(ip))
  local token, err = login.ensure_token(ip)
  if not token then
    return nil, "No token: " .. tostring(err)
  end

  local resp = {}
  local res, code, _, status = http.request{
    url = "http://" .. ip .. "/xled/v1/led/mode",
    method = "GET",
    headers = { ["X-Auth-Token"] = token },
    sink = ltn12.sink.table(resp),
  }

  local body = table.concat(resp)
  if not res or code ~= 200 then
    return nil, "Failed to get mode: " .. tostring(status) .. " Body: " .. body
  end

  local decoded, _, jerr = json.decode(body)
  if not decoded then
    return nil, "Invalid JSON: " .. tostring(jerr) .. " Body: " .. body
  end

  local raw_mode = decoded.mode
  log.debug("[get_mode] raw mode: " .. tostring(raw_mode))
  return raw_mode
end

return mode