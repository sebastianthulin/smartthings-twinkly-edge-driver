local http = require "http"
local json = require "json"
local ltn12 = require "ltn12"
local socket = require "socket" -- for sleep
local twinkly = {}
local BASE_URL = "/xled/v1"

-- helper request
local function request(method, url, body)
  local res, resp = {}, nil
  local ok, err = pcall(function()
    local r, c, h = http.request{
      method = method,
      url = url,
      headers = { ["Content-Type"] = "application/json" },
      source = body and ltn12.source.string(body) or nil,
      sink = ltn12.sink.table(res),
    }
    if r then resp = table.concat(res) end
  end)
  if not ok then return nil, err end
  return resp
end

-- basic control (already present)
function twinkly.set_mode(ip, mode)
  local url = "http://" .. ip .. BASE_URL .. "/mode"
  local body = json.encode({ mode = mode })
  return request("POST", url, body)
end

function twinkly.set_brightness(ip, brightness)
  local url = "http://" .. ip .. BASE_URL .. "/led/out/brightness"
  local body = json.encode({ brightness = brightness })
  return request("POST", url, body)
end

function twinkly.get_brightness(ip)
  local url = "http://" .. ip .. BASE_URL .. "/led/out/brightness"
  local res = request("GET", url)
  if not res then return nil end
  local data = json.decode(res)
  return data and data.brightness or nil
end

function twinkly.set_color_rgb(ip, r, g, b)
  local url = "http://" .. ip .. BASE_URL .. "/led/color"
  local body = json.encode({ r = r, g = g, b = b })
  return request("POST", url, body)
end

function twinkly.get_color(ip)
  local url = "http://" .. ip .. BASE_URL .. "/led/color"
  local res = request("GET", url)
  if not res then return nil end
  local data = json.decode(res)
  return data
end

function twinkly.set_color_hsv(ip, h, s, v)
  local c = v * s
  local x = c * (1 - math.abs((h / 60) % 2 - 1))
  local m = v - c
  local r1, g1, b1
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
  local r = math.floor((r1 + m) * 255 + 0.5)
  local g = math.floor((g1 + m) * 255 + 0.5)
  local b = math.floor((b1 + m) * 255 + 0.5)
  return twinkly.set_color_rgb(ip, r, g, b)
end

-- smooth fade helpers
function twinkly.fade_brightness(ip, from_brightness, to_brightness, duration_ms)
  local steps = 10
  local delay = (duration_ms or 1000) / steps / 1000
  for i = 1, steps do
    local t = i / steps
    local b = math.floor(from_brightness + (to_brightness - from_brightness) * t + 0.5)
    twinkly.set_brightness(ip, b)
    socket.sleep(delay)
  end
  return true
end

function twinkly.fade_color(ip, fr, fg, fb, tr, tg, tb, duration_ms)
  local steps = 15
  local delay = (duration_ms or 1000) / steps / 1000
  for i = 1, steps do
    local t = i / steps
    local r = math.floor(fr + (tr - fr) * t + 0.5)
    local g = math.floor(fg + (tg - fg) * t + 0.5)
    local b = math.floor(fb + (tb - fb) * t + 0.5)
    twinkly.set_color_rgb(ip, r, g, b)
    socket.sleep(delay)
  end
  return true
end

return twinkly