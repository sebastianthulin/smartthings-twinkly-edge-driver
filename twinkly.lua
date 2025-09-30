local http = require "socket.http"
local ltn12 = require "ltn12"
local json = require "dkjson"

local twinkly = {}

local function login(ip)
  if not ip then return nil end
  local login_body = json.encode({ challenge = "AAAAAAAAAAAAAAAAAAAAAA==" })
  local resp = {}
  local res, code, headers, status = http.request{
    url = "http://" .. ip .. "/xled/v1/login",
    method = "POST",
    headers = {
      ["Content-Type"] = "application/json",
      ["Content-Length"] = tostring(#login_body)
    },
    source = ltn12.source.string(login_body),
    sink = ltn12.sink.table(resp),
  }
  if not res then return nil end
  local body = table.concat(resp)
  local decoded = json.decode(body) or {}
  return decoded.authentication_token
end

function twinkly.set_mode(ip, mode)
  local token = login(ip)
  if not token then return nil end
  local body = json.encode({ mode = mode })
  http.request{
    url = "http://" .. ip .. "/xled/v1/led/mode",
    method = "POST",
    headers = {
      ["Content-Type"] = "application/json",
      ["Content-Length"] = tostring(#body),
      ["X-Auth-Token"] = token
    },
    source = ltn12.source.string(body),
    sink = ltn12.sink.null(),
  }
  return true
end

function twinkly.get_mode(ip)
  local token = login(ip)
  if not token then return nil end
  local resp = {}
  local ok, code, headers, status = http.request{
    url = "http://" .. ip .. "/xled/v1/led/mode",
    method = "GET",
    headers = {
      ["X-Auth-Token"] = token
    },
    sink = ltn12.sink.table(resp),
  }
  if not ok then return nil end
  local body = table.concat(resp)
  local decoded = json.decode(body) or {}
  return decoded.mode
end

return twinkly
