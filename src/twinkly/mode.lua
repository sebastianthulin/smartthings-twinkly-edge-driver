local http = require "socket.http"
local ltn12 = require "ltn12"
local json = require "dkjson"
local login = require "twinkly.login"

local mode = {}

function mode.get_mode(ip)
  print("[get_mode] Entering with IP: " .. tostring(ip))
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
  if raw_mode == "off" then
    print("[get_mode] Normalized mode: off")
    return "off", body
  else
    print("[get_mode] Normalized mode: on (raw was " .. tostring(raw_mode) .. ")")
    return "on", body
  end
end

return mode