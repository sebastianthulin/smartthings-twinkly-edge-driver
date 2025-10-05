-- test_color_mapping.lua
-- Usage: lua test_color_mapping.lua 192.168.87.32

package.path = package.path .. ";src/?.lua"
_G.IS_LOCAL_TEST = true -- ensures blocking socket is used locally

local login = require "twinkly.login"
local http = require("twinkly.http").http
local ltn12 = require "ltn12"
local json = require "dkjson"
local socket = require "socket"

local ip = arg[1]
if not ip then
  print("Usage: lua test_color_mapping.lua <ip>")
  os.exit(1)
end

local function post_color(r,g,b)
  local token, err = login.ensure_token(ip)
  if not token then
    print("login failed:", err); return nil
  end
  local body = json.encode({ red = r, green = g, blue = b })
  local resp = {}
  local ok, code = http.request{
    url = "http://" .. ip .. "/xled/v1/led/color",
    method = "POST",
    headers = {
      ["Content-Type"] = "application/json",
      ["Content-Length"] = tostring(#body),
      ["X-Auth-Token"] = token
    },
    source = ltn12.source.string(body),
    sink = ltn12.sink.table(resp),
  }
  return ok, code, table.concat(resp)
end

local function get_color()
  local token, err = login.ensure_token(ip)
  if not token then
    print("login failed:", err); return nil
  end
  local resp = {}
  local ok, code = http.request{
    url = "http://" .. ip .. "/xled/v1/led/color",
    method = "GET",
    headers = { ["X-Auth-Token"] = token },
    sink = ltn12.sink.table(resp)
  }
  if not ok then return nil end
  local body = table.concat(resp)
  local decoded, _, jerr = json.decode(body)
  if not decoded then
    print("JSON decode error:", jerr, "body:", body)
    return nil
  end
  return decoded
end

local function test_one(r,g,b)
  print(string.format("Sending %d,%d,%d", r,g,b))
  local ok, code, body = post_color(r,g,b)
  print("POST ok:", ok, "code:", code, "body:", body)
  socket.sleep(0.35)
  local c = get_color()
  if not c then print("Failed to read color") end
  print("Read back:", c and string.format("r=%s g=%s b=%s", tostring(c.red), tostring(c.green), tostring(c.blue)) or "nil")
  return c
end

print("Testing color mapping for", ip)
local rcol = test_one(255,0,0)
socket.sleep(0.2)
local gcol = test_one(0,255,0)
socket.sleep(0.2)
local bcol = test_one(0,0,255)

local function maxcomp(col)
  if not col then return nil end
  local m = math.max(col.red or 0, col.green or 0, col.blue or 0)
  if m == (col.red or 0) then return "red" end
  if m == (col.green or 0) then return "green" end
  return "blue"
end

print("Mapping: sent red ->", maxcomp(rcol), " sent green ->", maxcomp(gcol), " sent blue ->", maxcomp(bcol))