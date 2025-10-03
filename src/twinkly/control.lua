local http = require("twinkly.http").http
local ltn12 = require "ltn12"
local json = require "dkjson"
local login = require "twinkly.login"
local ok, log = pcall(require, "log")
if not ok then
  log = {
    debug = function(...) print("[DEBUG]", ...) end,
    info  = function(...) print("[INFO]", ...) end,
    warn  = function(...) print("[WARN]", ...) end,
    error = function(...) print("[ERROR]", ...) end,
  }
end

local control = {}

function control.set_mode(ip, mode)
  log.debug("Sending set_mode=" .. tostring(mode) .. " to " .. tostring(ip))
  local token, err = login.ensure_token(ip)
  if not token then
    log.error("No token for " .. tostring(ip) .. ": " .. tostring(err))
    return nil, err
  end

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
  log.debug("HTTP response code=" .. tostring(code) .. " body=" .. tostring(resp_body))

  if not res or code ~= 200 then
    log.warn("Failed to set mode on " .. tostring(ip) .. ": " .. tostring(status) .. " Body: " .. resp_body)
    return nil, "Failed to set mode: " .. tostring(status) .. " Body: " .. resp_body
  end

  return true, resp_body
end

return control