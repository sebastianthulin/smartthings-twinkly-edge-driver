local cosock = require "cosock"
local http = cosock.asyncify("socket.http")
local ltn12 = require "ltn12"
local json = require "dkjson"
local utils = require "twinkly.utils"
local log = require "log"

local login = {}
local sessions = {}

function login.login(ip)
  if not ip then return nil, "No IP provided" end

  -- Step 1: login with challenge
  local challenge = utils.random_base64(16)
  local login_body = json.encode({ challenge = challenge })
  local resp = {}
  local res, code, _, status = http.request{
    url = "http://" .. ip .. "/xled/v1/login",
    method = "POST",
    headers = {
      ["Content-Type"] = "application/json",
      ["Content-Length"] = tostring(#login_body)
    },
    source = ltn12.source.string(login_body),
    sink = ltn12.sink.table(resp),
  }
  if not res or code ~= 200 then
    log.warn("Login failed to " .. tostring(ip) .. ": " .. tostring(status))
    return nil, "Login failed: " .. tostring(status)
  end

  local body = table.concat(resp)
  log.debug("[login] Raw body: " .. tostring(body))
  local decoded = json.decode(body)
  if not decoded or not decoded.authentication_token or not decoded["challenge-response"] then
    return nil, "Login response missing fields. Body: " .. body
  end

  local token = decoded.authentication_token

  -- Step 2: verify challenge-response
  local verify_body = json.encode({ ["challenge-response"] = decoded["challenge-response"] })
  local vresp = {}
  local vres, vcode, _, vstatus = http.request{
    url = "http://" .. ip .. "/xled/v1/verify",
    method = "POST",
    headers = {
      ["Content-Type"] = "application/json",
      ["Content-Length"] = tostring(#verify_body),
      ["X-Auth-Token"] = token
    },
    source = ltn12.source.string(verify_body),
    sink = ltn12.sink.table(vresp),
  }
  local vbody = table.concat(vresp)
  log.debug("[verify] Raw body: " .. tostring(vbody))
  if not vres or vcode ~= 200 then
    return nil, "Verify failed: " .. tostring(vstatus) .. " Body: " .. vbody
  end

  -- Cache token for reuse
  sessions[ip] = token
  return token
end

function login.ensure_token(ip)
  if sessions[ip] then
    return sessions[ip]
  end
  return login.login(ip)
end

return login