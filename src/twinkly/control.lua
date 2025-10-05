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

-- 🧩 Adjustable saturation curve factor (higher = more saturation retained)
local SATURATION_SCALE = 1.8

------------------------------------------------------------
-- Mode helper
------------------------------------------------------------
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

  local res, code, status, resp_body = do_set_mode(ip, mode, token)
  if code == 401 then
    log.warn("Unauthorized (401), clearing token and retrying...")
    login.clear_token(ip)
    local new_token, nerr = login.ensure_token(ip)
    if not new_token then return nil, nerr end
    res, code, status, resp_body = do_set_mode(ip, mode, new_token)
  end

  if not res or code ~= 200 then
    return nil, "Failed to set mode: " .. tostring(status)
  end
  return true, resp_body
end

------------------------------------------------------------
-- Unified HTTP request with auto token management
------------------------------------------------------------
local function do_request(ip, endpoint, method, body, token)
  local resp = {}
  local headers = { ["X-Auth-Token"] = token }
  if body then
    headers["Content-Type"] = "application/json"
    headers["Content-Length"] = tostring(#body)
  end

  local res, code, _, status = http.request{
    url = "http://" .. ip .. endpoint,
    method = method or "GET",
    headers = headers,
    source = body and ltn12.source.string(body) or nil,
    sink = ltn12.sink.table(resp),
  }
  return res, code, status, table.concat(resp)
end

-- 🧠 Centralized retry logic
local function make_request(ip, endpoint, method, payload)
  -- Always try to ensure token before any request
  local token, err = login.ensure_token(ip)
  if not token then
    log.error("No token for " .. tostring(ip) .. ": " .. tostring(err))
    return nil, err
  end

  local body = payload and json.encode(payload) or nil
  local res, code, status, resp_body = do_request(ip, endpoint, method, body, token)

  -- Debug info
  log.debug(string.format("[HTTP %s %s] code=%s body=%s", method or "GET", endpoint, tostring(code), tostring(resp_body)))

  -- Handle invalid or expired token globally
  if code == 401 or (resp_body and resp_body:match("Invalid Token")) then
    log.warn(string.format("[%s] 401 or Invalid Token -> clearing token & retrying", endpoint))

    -- Always clear token
    login.clear_token(ip)

    -- Wait briefly before retry (Twinkly needs a small pause before reauth)
    if socket and socket.sleep then socket.sleep(0.5) end

    -- Try again with a *fresh* token
    local new_token, new_err = login.ensure_token(ip)
    if not new_token then
      log.error("Re-login failed for " .. tostring(ip) .. ": " .. tostring(new_err))
      return nil, new_err
    end

    res, code, status, resp_body = do_request(ip, endpoint, method, body, new_token)
    log.debug(string.format("[RETRY %s %s] code=%s body=%s", method or "GET", endpoint, tostring(code), tostring(resp_body)))

    -- Final safeguard
    if code == 401 or (resp_body and resp_body:match("Invalid Token")) then
      log.warn(string.format("[%s] Giving up for %s after retry", endpoint, ip))
      return nil, "Invalid Token after retry"
    end
  end

  if not res or code ~= 200 then
    return nil, string.format("Request failed: %s (code=%s, body=%s)", endpoint, tostring(code), tostring(resp_body))
  end

  return res, code, status, resp_body
end

------------------------------------------------------------
-- Brightness
------------------------------------------------------------
function control.set_brightness(ip, level)
  local res, code, status, resp_body = make_request(ip, "/xled/v1/led/out/brightness", "POST", { value = level })
  if not res or code ~= 200 then return nil, status end
  return true, resp_body
end

function control.get_brightness(ip)
  local res, code, status, resp_body = make_request(ip, "/xled/v1/led/out/brightness", "GET")
  if not res or code ~= 200 then return nil end
  local decoded = json.decode(resp_body)
  return decoded and decoded.value or 0
end

------------------------------------------------------------
-- Color (standard RGB order)
------------------------------------------------------------
function control.set_color_rgb(ip, red, green, blue)
  log.debug(string.format("Setting color RGB(%d,%d,%d) to %s", red, green, blue, ip))
  local ok, err = control.set_mode(ip, "color")
  if not ok then return nil, err end

  local payload = { red = red, green = green, blue = blue }
  local res, code, status, resp_body = make_request(ip, "/xled/v1/led/color", "POST", payload)
  if not res or code ~= 200 then return nil, status end
  return true, resp_body
end

------------------------------------------------------------
-- HSV → RGB conversion with gamma & saturation scaling
------------------------------------------------------------
local function hsv_to_rgb(h, s, v)
  s = math.pow(s, 1 / SATURATION_SCALE)

  local c = v * s
  local x = c * (1 - math.abs((h / 60) % 2 - 1))
  local m = v - c
  local r, g, b

  if h < 60 then r,g,b = c,x,0
  elseif h < 120 then r,g,b = x,c,0
  elseif h < 180 then r,g,b = 0,c,x
  elseif h < 240 then r,g,b = 0,x,c
  elseif h < 300 then r,g,b = x,0,c
  else r,g,b = c,0,x end

  local gamma = 2.2
  r = math.pow(r + m, 1 / gamma)
  g = math.pow(g + m, 1 / gamma)
  b = math.pow(b + m, 1 / gamma)

  return math.floor(r * 255), math.floor(g * 255), math.floor(b * 255)
end

function control.set_color_hsv(ip, hue, saturation, value)
  saturation = (saturation or 0) / 100
  value = (value or 100) / 100
  hue = (hue or 0) * 3.6
  local r, g, b = hsv_to_rgb(hue, saturation, value)
  return control.set_color_rgb(ip, r, g, b)
end

------------------------------------------------------------
-- Get color
------------------------------------------------------------
function control.get_color(ip)
  local res, code, status, resp_body = make_request(ip, "/xled/v1/led/color", "GET")
  if not res or code ~= 200 then return nil end
  local decoded = json.decode(resp_body)
  return {
    red = decoded.red or 0,
    green = decoded.green or 0,
    blue = decoded.blue or 0
  }
end

return control