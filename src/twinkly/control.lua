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

local function do_set_mode(ip, mode, token)
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
  return res, code, status, table.concat(resp)
end

function control.set_mode(ip, mode)
  log.debug("Sending set_mode=" .. tostring(mode) .. " to " .. tostring(ip))
  local token, err = login.ensure_token(ip)
  if not token then
    log.error("No token for " .. tostring(ip) .. ": " .. tostring(err))
    return nil, err
  end

  -- First attempt
  local res, code, status, resp_body = do_set_mode(ip, mode, token)
  log.debug("HTTP response code=" .. tostring(code) .. " body=" .. tostring(resp_body))

  -- Retry once if token is invalid
  if code == 401 then
    log.warn("Unauthorized (401), clearing token and retrying...")
    login.clear_token(ip)
    local new_token, nerr = login.ensure_token(ip)
    if not new_token then
      return nil, "Re-login failed: " .. tostring(nerr)
    end
    res, code, status, resp_body = do_set_mode(ip, mode, new_token)
    log.debug("Retry response code=" .. tostring(code) .. " body=" .. tostring(resp_body))
  end

  if not res or code ~= 200 then
    log.warn("Failed to set mode on " .. tostring(ip) .. ": " .. tostring(status) .. " Body: " .. resp_body)
    return nil, "Failed to set mode: " .. tostring(status) .. " Body: " .. resp_body
  end

  return true, resp_body
end

return control