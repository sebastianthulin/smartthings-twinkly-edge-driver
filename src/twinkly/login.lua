local http = require("twinkly.http").http
local ltn12 = require "ltn12"
local json = require "dkjson"
local utils = require "twinkly.utils"
local config = require "twinkly.config"

local ok, log = pcall(require, "log")
if not ok then
  log = {
    debug = function(...) print("[DEBUG]", ...) end,
    info  = function(...) print("[INFO]", ...) end,
    warn  = function(...) print("[WARN]", ...) end,
    error = function(...) print("[ERROR]", ...) end,
  }
end

local login = {}
local sessions = {}

-----------------------------------------------------------
-- 🧹 Clear a cached token
-----------------------------------------------------------
function login.clear_token(ip)
  if sessions[ip] then
    log.debug("[login] Clearing token for " .. tostring(ip))
    sessions[ip] = nil
  end
end

-----------------------------------------------------------
-- 🔐 Perform full login + verify handshake
-----------------------------------------------------------
function login.login(ip)
  if not ip then return nil, "No IP provided" end

  local challenge = utils.random_base64(16)
  local login_body = json.encode({ challenge = challenge })
  local resp = {}

  -- Step 1: POST /login
  local res, code, _, status = http.request{
    url = config.build_url(ip, "login"),
    method = "POST",
    headers = {
      ["Content-Type"] = config.api.content_type,
      [config.http.content_length_header] = tostring(#login_body)
    },
    source = ltn12.source.string(login_body),
    sink = ltn12.sink.table(resp),
  }

  if not res or code ~= config.http.success_code then
    log.warn("[login] Failed to login to " .. tostring(ip) .. ": " .. tostring(status))
    return nil, "Login failed: " .. tostring(status)
  end

  local body = table.concat(resp)
  log.debug("[login] Raw body: " .. tostring(body))
  local decoded = json.decode(body)
  if not decoded or not decoded.authentication_token or not decoded["challenge-response"] then
    return nil, "Login response missing fields. Body: " .. body
  end

  local token = decoded.authentication_token
  local challenge_response = decoded["challenge-response"]

  -- Step 2: POST /verify
  local verify_body = json.encode({ ["challenge-response"] = challenge_response })
  local vresp = {}
  local vres, vcode, _, vstatus = http.request{
    url = config.build_url(ip, "verify"),
    method = "POST",
    headers = {
      ["Content-Type"] = config.api.content_type,
      [config.http.content_length_header] = tostring(#verify_body),
      [config.http.auth_header] = token
    },
    source = ltn12.source.string(verify_body),
    sink = ltn12.sink.table(vresp),
  }

  local vbody = table.concat(vresp)
  log.debug("[verify] Raw body: " .. tostring(vbody))
  if not vres or vcode ~= config.http.success_code then
    log.warn("[verify] Verify failed for " .. ip .. ": " .. tostring(vstatus))
    return nil, "Verify failed: " .. tostring(vstatus)
  end

  -- Step 3: Cache token
  sessions[ip] = token
  log.info("[login] Logged in successfully for " .. ip)
  return token
end

-----------------------------------------------------------
-- 🧠 Ensure valid token (auto re-login if invalid)
-----------------------------------------------------------
function login.ensure_token(ip)
  local token = sessions[ip]

  -- ✅ Validate existing token with a quick /verify call
  if token then
    local resp = {}
    local res, code = http.request{
      url = config.build_url(ip, "verify"),
      method = "POST",
      headers = {
        [config.http.auth_header] = token,
        ["Content-Type"] = config.api.content_type,
        [config.http.content_length_header] = "2"
      },
      source = ltn12.source.string("{}"),
      sink = ltn12.sink.table(resp),
    }

    if res and code == config.http.success_code then
      log.debug("[ensure_token] Existing token still valid for " .. ip)
      return token
    else
      log.warn("[ensure_token] Token invalid for " .. ip .. ", clearing...")
      sessions[ip] = nil
    end
  end

  -- 🚀 No valid token — perform full login
  log.debug("[ensure_token] Performing login for " .. tostring(ip))
  local new_token, err = login.login(ip)
  if not new_token then
    log.error("[ensure_token] Failed to get new token for " .. tostring(ip) .. ": " .. tostring(err))
    return nil, err
  end

  return new_token
end

-----------------------------------------------------------
-- 🔍 Debug helper
-----------------------------------------------------------
function login.dump_sessions()
  for ip, token in pairs(sessions) do
    log.debug(string.format("[session] %s => %s", ip, token))
  end
end

return login