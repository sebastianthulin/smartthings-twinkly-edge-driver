local http = require("twinkly.http").http
local ltn12 = require "ltn12"
local json = require "dkjson"
local login = require "twinkly.login"
local socket = require "socket" -- for short sleep between reauth retries
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

local control = {}



------------------------------------------------------------
-- Mode helper
------------------------------------------------------------
local function do_set_mode(ip, mode, token)
  local body = json.encode({ mode = mode })
  local resp = {}
  local res, code, _, status = http.request{
    url = config.build_url(ip, "mode"),
    method = "POST",
    headers = {
      ["Content-Type"] = config.api.content_type,
      [config.http.content_length_header] = tostring(#body),
      [config.http.auth_header] = token
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
  if code == config.http.unauthorized_code or (resp_body and resp_body:match(config.http.invalid_token_pattern)) then
    log.warn("Unauthorized (401) or invalid token in set_mode, retrying...")
    login.clear_token(ip)
    socket.sleep(config.timing.reauth_delay)
    local new_token, nerr = login.ensure_token(ip)
    if not new_token then return nil, nerr end
    res, code, status, resp_body = do_set_mode(ip, mode, new_token)
  end

  if not res or code ~= config.http.success_code then
    return nil, "Failed to set mode: " .. tostring(status)
  end
  return true, resp_body
end

------------------------------------------------------------
-- Unified HTTP request with automatic token recovery
------------------------------------------------------------
local function do_request(ip, endpoint, method, body, token)
  local resp = {}
  local headers = { [config.http.auth_header] = token }
  if body then
    headers["Content-Type"] = config.api.content_type
    headers[config.http.content_length_header] = tostring(#body)
  end

  local res, code, _, status = http.request{
    url = config.api.protocol .. ip .. endpoint,
    method = method or "GET",
    headers = headers,
    source = body and ltn12.source.string(body) or nil,
    sink = ltn12.sink.table(resp),
  }

  return res, code, status, table.concat(resp)
end

------------------------------------------------------------
-- 🧠 Centralized token-aware request logic
------------------------------------------------------------
local function make_request(ip, endpoint, method, payload)
  -- Always ensure valid token before any request
  local token, err = login.ensure_token(ip)
  if not token then
    log.error("No token for " .. tostring(ip) .. ": " .. tostring(err))
    return nil, err
  end

  local body = payload and json.encode(payload) or nil
  local res, code, status, resp_body = do_request(ip, endpoint, method, body, token)

  log.debug(string.format("[HTTP %s %s] code=%s body=%s", method or "GET", endpoint, tostring(code), tostring(resp_body)))

  -- Token expired or taken by Twinkly app
  if code == config.http.unauthorized_code or (resp_body and resp_body:match(config.http.invalid_token_pattern)) then
    log.warn(string.format("[%s] Token invalid — refreshing session for %s", endpoint, ip))
    login.clear_token(ip)
    socket.sleep(config.timing.token_refresh_delay)

    local new_token, nerr = login.ensure_token(ip)
    if not new_token then
      log.error("Re-login failed for " .. tostring(ip) .. ": " .. tostring(nerr))
      return nil, nerr
    end

    res, code, status, resp_body = do_request(ip, endpoint, method, body, new_token)
    log.debug(string.format("[RETRY %s %s] code=%s body=%s", method or "GET", endpoint, tostring(code), tostring(resp_body)))

    -- Twinkly can take 1–2 polls to stabilize after app interference
    if code == config.http.unauthorized_code or (resp_body and resp_body:match(config.http.invalid_token_pattern)) then
      log.warn(string.format("[%s] Giving up after retry for %s", endpoint, ip))
      return nil, "Invalid Token after retry"
    end
  end

  if not res or code ~= config.http.success_code then
    log.warn(string.format("[HTTP %s %s] Failed: code=%s body=%s", method or "GET", endpoint, tostring(code), tostring(resp_body)))
    return nil, string.format("Request failed: %s (code=%s)", endpoint, tostring(code))
  end

  return res, code, status, resp_body
end

------------------------------------------------------------
-- Brightness
------------------------------------------------------------
function control.set_brightness(ip, level)
  local ok, code, status, body = make_request(ip, config.get_endpoint("brightness"), "POST", { value = level })
  if not ok then return nil, status end
  return true, body
end

function control.get_brightness(ip)
  local ok, code, status, body = make_request(ip, config.get_endpoint("brightness"), "GET")
  if not ok then return nil end
  local decoded = json.decode(body)
  return decoded and decoded.value or 0
end

------------------------------------------------------------
-- Color handling (standard RGB order)
------------------------------------------------------------
function control.set_color_rgb(ip, red, green, blue)
  log.debug(string.format("Setting RGB(%d,%d,%d) -> %s", red, green, blue, ip))
  local ok, err = control.set_mode(ip, "color")
  if not ok then return nil, err end

  local payload = { red = red, green = green, blue = blue }
  local ok2, code, status, body = make_request(ip, config.get_endpoint("color"), "POST", payload)
  if not ok2 then return nil, status end
  return true, body
end

------------------------------------------------------------
-- HSV → RGB conversion with gamma + saturation scaling
------------------------------------------------------------
local function hsv_to_rgb(h, s, v)
  s = math.pow(s, 1 / config.color.saturation_scale)
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

  r = math.pow(r + m, 1 / config.color.gamma)
  g = math.pow(g + m, 1 / config.color.gamma)
  b = math.pow(b + m, 1 / config.color.gamma)

  return math.floor(r * config.color.max_rgb_value), math.floor(g * config.color.max_rgb_value), math.floor(b * config.color.max_rgb_value)
end

function control.set_color_hsv(ip, hue, saturation, value)
  saturation = (saturation or 0) / config.color.max_percentage
  value = (value or config.color.max_percentage) / config.color.max_percentage
  hue = (hue or 0) * (config.color.max_hue_degrees / config.color.max_percentage)
  local r, g, b = hsv_to_rgb(hue, saturation, value)
  return control.set_color_rgb(ip, r, g, b)
end

------------------------------------------------------------
-- Get color
------------------------------------------------------------
function control.get_color(ip)
  local ok, code, status, body = make_request(ip, config.get_endpoint("color"), "GET")
  if not ok then return nil end
  local decoded = json.decode(body)
  return decoded and {
    red = decoded.red or 0,
    green = decoded.green or 0,
    blue = decoded.blue or 0
  } or nil
end

return control