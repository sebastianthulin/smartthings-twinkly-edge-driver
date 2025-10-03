local cosock = require "cosock"
local http = cosock.asyncify("socket.http")
local ltn12 = require "ltn12"
local json = require "dkjson"
local login = require "twinkly.login"
local log = require "log"

local control = {}

function control.set_mode(ip, mode)
  local token, err = login.ensure_token(ip)
  if not token then return nil, "No token: " .. tostring(err) end

  local body = json.encode({ mode = mode })
  local resp = {}
  local res, code, _, status = http.request{
    url = "http://" .. ip .. "/xled/v1/led/mode",
    method = "POST",
    headers = {
      ["Content-Type"] = "application/json",
      ["Content-Length"] = tostring(#body),
      ["X-Auth-Token"] = token
    },
    source = ltn12.source.string(body),
    sink = ltn12.sink.table(resp),
  }

  local resp_body = table.concat(resp)
  if not res or code ~= 200 then
    log.warn("Failed to set mode on " .. tostring(ip) .. ": " .. tostring(status) .. " Body: " .. resp_body)
    return nil, "Failed to set mode: " .. tostring(status) .. " Body: " .. resp_body
  end

  return true, resp_body
end

return control