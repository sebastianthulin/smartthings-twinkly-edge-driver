local twinkly = require "twinkly"
local args = {...}
if #args < 2 then
  print("Usage: lua test.lua <command> <ip>")
  print("Commands: on, off, get")
  os.exit(1)
end

local cmd = args[1]
local ip = args[2]

if cmd == "on" then
  print("Turning ON Twinkly at " .. ip)
  twinkly.set_mode(ip, "movie")
  print("Done.")
elseif cmd == "off" then
  print("Turning OFF Twinkly at " .. ip)
  twinkly.set_mode(ip, "off")
  print("Done.")
elseif cmd == "get" then
  local mode = twinkly.get_mode(ip)
  print("Twinkly at " .. ip .. " is in mode: " .. tostring(mode))
else
  print("Unknown command: " .. cmd)
end
