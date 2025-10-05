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

-- Generic HTTP request helper with token retry logic
local function do_request(ip, endpoint, method, body, token)
  local resp = {}
  local headers = {
    ["X-Auth-Token"] = token
  }
  
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

-- Generic function with retry logic
local function make_request(ip, endpoint, method, payload)
  local token, err = login.ensure_token(ip)
  if not token then
    log.error("No token for " .. tostring(ip) .. ": " .. tostring(err))
    return nil, err
  end

  local body = payload and json.encode(payload) or nil
  local res, code, status, resp_body = do_request(ip, endpoint, method, body, token)
  log.debug("HTTP " .. (method or "GET") .. " " .. endpoint .. " response code=" .. tostring(code) .. " body=" .. tostring(resp_body))

  -- Retry once if token is invalid
  if code == 401 then
    log.warn("Unauthorized (401), clearing token and retrying...")
    login.clear_token(ip)
    local new_token, nerr = login.ensure_token(ip)
    if not new_token then
      return nil, "Re-login failed: " .. tostring(nerr)
    end
    res, code, status, resp_body = do_request(ip, endpoint, method, body, new_token)
    log.debug("Retry response code=" .. tostring(code) .. " body=" .. tostring(resp_body))
  end

  return res, code, status, resp_body
end

-- Set brightness (0-100)
function control.set_brightness(ip, level)
  log.debug("Setting brightness=" .. tostring(level) .. " to " .. tostring(ip))
  if not level or level < 0 or level > 100 then
    return nil, "Invalid brightness level: " .. tostring(level)
  end
  
  local res, code, status, resp_body = make_request(ip, "/xled/v1/led/out/brightness", "POST", { value = level })
  
  if not res or code ~= 200 then
    log.warn("Failed to set brightness on " .. tostring(ip) .. ": " .. tostring(status) .. " Body: " .. resp_body)
    return nil, "Failed to set brightness: " .. tostring(status) .. " Body: " .. resp_body
  end

  return true, resp_body
end

-- Get brightness
function control.get_brightness(ip)
  log.debug("Getting brightness from " .. tostring(ip))
  local res, code, status, resp_body = make_request(ip, "/xled/v1/led/out/brightness", "GET")
  
  if not res or code ~= 200 then
    log.warn("Failed to get brightness from " .. tostring(ip) .. ": " .. tostring(status) .. " Body: " .. resp_body)
    return nil, "Failed to get brightness: " .. tostring(status) .. " Body: " .. resp_body
  end

  local decoded, _, jerr = json.decode(resp_body)
  if not decoded then
    return nil, "Invalid JSON: " .. tostring(jerr) .. " Body: " .. resp_body
  end

  return decoded.value or 0
end

-- Set color using RGB values (0-255 each)
function control.set_color_rgb(ip, red, green, blue)
  log.debug("Setting color RGB(" .. tostring(red) .. "," .. tostring(green) .. "," .. tostring(blue) .. ") to " .. tostring(ip))
  
  if not red or not green or not blue or 
     red < 0 or red > 255 or 
     green < 0 or green > 255 or 
     blue < 0 or blue > 255 then
    return nil, "Invalid RGB values"
  end
  
  -- Ensure mode is set to "color" before setting color
  local ok, err = control.set_mode(ip, "color")
  if not ok then
    log.warn("Failed to set mode to color on " .. tostring(ip) .. ": " .. tostring(err))
    return nil, "Failed to set mode to color: " .. tostring(err)
  end
  
  -- Twinkly LEDs use GRB channel order
  local res, code, status, resp_body = make_request(ip, "/xled/v1/led/color", "POST", { 
    red = green,   -- swap red and green (neopixel order)
    green = red,
    blue = blue
  })
  
  if not res or code ~= 200 then
    log.warn("Failed to set color on " .. tostring(ip) .. ": " .. tostring(status) .. " Body: " .. resp_body)
    return nil, "Failed to set color: " .. tostring(status) .. " Body: " .. resp_body
  end

  return true, resp_body
end

-- Set color using HSV values (hue: 0-360, saturation: 0-100, value: 0-100)
function control.set_color_hsv(ip, hue, saturation, value)
  log.debug("Setting color HSV(" .. tostring(hue) .. "," .. tostring(saturation) .. "," .. tostring(value) .. ") to " .. tostring(ip))
  
  -- Convert HSV to RGB
  hue = hue or 0
  saturation = (saturation or 0) / 100
  value = (value or 100) / 100
  
  local c = value * saturation
  local x = c * (1 - math.abs((hue / 60) % 2 - 1))
  local m = value - c
  
  local r, g, b
  if hue >= 0 and hue < 60 then
    r, g, b = c, x, 0
  elseif hue >= 60 and hue < 120 then
    r, g, b = x, c, 0
  elseif hue >= 120 and hue < 180 then
    r, g, b = 0, c, x
  elseif hue >= 180 and hue < 240 then
    r, g, b = 0, x, c
  elseif hue >= 240 and hue < 300 then
    r, g, b = x, 0, c
  else
    r, g, b = c, 0, x
  end
  
  local red = math.floor((r + m) * 255)
  local green = math.floor((g + m) * 255)
  local blue = math.floor((b + m) * 255)
  
  return control.set_color_rgb(ip, red, green, blue)
end

-- Get color
function control.get_color(ip)
  log.debug("Getting color from " .. tostring(ip))
  local res, code, status, resp_body = make_request(ip, "/xled/v1/led/color", "GET")
  
  if not res or code ~= 200 then
    log.warn("Failed to get color from " .. tostring(ip) .. ": " .. tostring(status) .. " Body: " .. resp_body)
    return nil, "Failed to get color: " .. tostring(status) .. " Body: " .. resp_body
  end

  local decoded, _, jerr = json.decode(resp_body)
  if not decoded then
    return nil, "Invalid JSON: " .. tostring(jerr) .. " Body: " .. resp_body
  end

  return {
    red = decoded.red or 0,
    green = decoded.green or 0,
    blue = decoded.blue or 0
  }
end

return control