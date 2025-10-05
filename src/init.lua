local http = require "socket.http"
local json = require "dkjson"
local ltn12 = require "ltn12"
local log = require "log"

local control = {}

local function make_request(ip, path, method, body)
  local url = "http://" .. ip .. path
  local body_str = body and json.encode(body) or nil
  local response_body = {}

  local res, code, status = http.request{
    url = url,
    method = method,
    headers = {
      ["Content-Type"] = "application/json",
      ["Content-Length"] = body_str and #body_str or 0,
    },
    source = body_str and ltn12.source.string(body_str) or nil,
    sink = ltn12.sink.table(response_body),
  }

  local resp_body = table.concat(response_body)
  return res, code, status, resp_body
end

function control.set_mode(ip, mode)
  local valid_modes = { off = true, movie = true, music = true, static = true }
  if not valid_modes[mode] then
    log.error("Invalid mode: " .. tostring(mode))
    return false, "Invalid mode"
  end

  local res, code, status, resp_body = make_request(ip, "/xled/v1/led/mode", "POST", { mode = mode })
  if code ~= 200 then
    return false, resp_body
  end
  return true, resp_body
end

function control.get_mode(ip)
  local res, code, status, resp_body = make_request(ip, "/xled/v1/led/mode", "GET")
  if code ~= 200 then
    return nil, resp_body
  end
  local data, pos, err = json.decode(resp_body)
  if err then
    return nil, err
  end
  return data.mode
end

function control.set_brightness(ip, level)
  -- level expected 0-100, convert to 0-255
  local brightness = math.floor(level * 255 / 100)
  local res, code, status, resp_body = make_request(ip, "/xled/v1/led/brightness", "POST", { brightness = brightness })
  if code ~= 200 then
    return false, resp_body
  end
  return true, resp_body
end

function control.get_brightness(ip)
  local res, code, status, resp_body = make_request(ip, "/xled/v1/led/brightness", "GET")
  if code ~= 200 then
    return nil, resp_body
  end
  local data, pos, err = json.decode(resp_body)
  if err then
    return nil, err
  end
  return data.brightness
end

function control.set_color_rgb(ip, red, green, blue)
  -- Twinkly LEDs use GRB channel order
  local res, code, status, resp_body = make_request(ip, "/xled/v1/led/color", "POST", { 
    red = green,   -- swap red and green
    green = red,
    blue = blue
  })
  if code ~= 200 then
    return false, resp_body
  end
  return true, resp_body
end

function control.get_color(ip)
  local res, code, status, resp_body = make_request(ip, "/xled/v1/led/color", "GET")
  if code ~= 200 then
    return nil, resp_body
  end
  local data, pos, err = json.decode(resp_body)
  if err then
    return nil, err
  end
  return data
end

function control.set_color_hsv(ip, hue, saturation, brightness)
  -- Convert HSV to RGB
  local h = hue * 360 / 100
  local s = saturation / 100
  local v = brightness / 100

  local c = v * s
  local x = c * (1 - math.abs((h / 60) % 2 - 1))
  local m = v - c

  local r1, g1, b1 = 0, 0, 0

  if h < 60 then
    r1, g1, b1 = c, x, 0
  elseif h < 120 then
    r1, g1, b1 = x, c, 0
  elseif h < 180 then
    r1, g1, b1 = 0, c, x
  elseif h < 240 then
    r1, g1, b1 = 0, x, c
  elseif h < 300 then
    r1, g1, b1 = x, 0, c
  else
    r1, g1, b1 = c, 0, x
  end

  local r = math.floor((r1 + m) * 255)
  local g = math.floor((g1 + m) * 255)
  local b = math.floor((b1 + m) * 255)

  return control.set_color_rgb(ip, r, g, b)
end

return control