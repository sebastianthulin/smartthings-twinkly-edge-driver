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

  local res, code, status, resp_body = do_set_mode(ip, mode, token)
  log.debug("HTTP response code=" .. tostring(code) .. " body=" .. tostring(resp_body))

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

-- Helper to make HTTP requests with token retry
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

local function make_request(ip, endpoint, method, payload)
  local token, err = login.ensure_token(ip)
  if not token then
    log.error("No token for " .. tostring(ip) .. ": " .. tostring(err))
    return nil, err
  end

  local body = payload and json.encode(payload) or nil
  local res, code, status, resp_body = do_request(ip, endpoint, method, body, token)
  log.debug("HTTP " .. (method or "GET") .. " " .. endpoint .. " response code=" .. tostring(code))

  if code == 401 then
    log.warn("Unauthorized (401), retrying after clearing token...")
    login.clear_token(ip)
    local new_token = login.ensure_token(ip)
    res, code, status, resp_body = do_request(ip, endpoint, method, body, new_token)
  end

  return res, code, status, resp_body
end

-- Brightness
function control.set_brightness(ip, level)
  log.debug("Setting brightness=" .. tostring(level) .. " to " .. tostring(ip))
  local res, code, status, resp_body = make_request(ip, "/xled/v1/led/out/brightness", "POST", { value = level })
  if not res or code ~= 200 then
    log.warn("Failed to set brightness: " .. tostring(status))
    return nil, status
  end
  return true, resp_body
end

function control.get_brightness(ip)
  local res, code, status, resp_body = make_request(ip, "/xled/v1/led/out/brightness", "GET")
  if not res or code ~= 200 then return nil end
  local decoded = json.decode(resp_body)
  return decoded and decoded.value or 0
end

-- Color (use proper RGB order)
function control.set_color_rgb(ip, red, green, blue)
  log.debug(string.format("Setting color RGB(%d,%d,%d) to %s", red, green, blue, ip))
  local ok, err = control.set_mode(ip, "color")
  if not ok then
    return nil, "Failed to set mode to color: " .. tostring(err)
  end

  -- Twinkly expects *standard RGB order* in recent firmware (was GRB before)
  local payload = {
    red = red,
    green = green,
    blue = blue
  }

  local res, code, status, resp_body = make_request(ip, "/xled/v1/led/color", "POST", payload)
  if not res or code ~= 200 then
    log.warn("Failed to set color: " .. tostring(status))
    return nil, status
  end
  return true, resp_body
end

-- HSV → RGB conversion (accurate + gamma)
local function hsv_to_rgb(h, s, v)
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

  -- gamma correction for more natural colors
  local gamma = 2.2
  r = math.pow(r + m, 1 / gamma)
  g = math.pow(g + m, 1 / gamma)
  b = math.pow(b + m, 1 / gamma)

  return math.floor(r * 255), math.floor(g * 255), math.floor(b * 255)
end

function control.set_color_hsv(ip, hue, saturation, value)
  saturation = (saturation or 0) / 100
  value = (value or 100) / 100
  hue = (hue or 0) * 3.6  -- SmartThings hue is 0–100
  local r, g, b = hsv_to_rgb(hue, saturation, value)
  return control.set_color_rgb(ip, r, g, b)
end

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