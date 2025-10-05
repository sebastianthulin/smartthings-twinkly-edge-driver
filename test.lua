package.path = package.path .. ";src/?.lua"

local twinkly = require "twinkly"
local args = {...}
if #args < 2 then
  print("Usage: lua test.lua <command> <ip> [param1] [param2] [param3]")
  print("Commands: on, off, get, brightness, color, rgb")
  print("  brightness <ip> <level>        - Set brightness 0-100")
  print("  color <ip> <hue> <sat> <val>   - Set HSV color")
  print("  rgb <ip> <red> <green> <blue>  - Set RGB color")
  print("  get <ip>                       - Get current state")
  os.exit(1)
end

local cmd = args[1]
local ip = args[2]

if cmd == "on" then
  print("Turning ON Twinkly at " .. ip)
  local ok, result = pcall(twinkly.set_mode, ip, "movie")
  if ok then
    print("Done: " .. tostring(result))
  else
    print("Error: " .. tostring(result))
  end
elseif cmd == "off" then
  print("Turning OFF Twinkly at " .. ip)
  local ok, result = pcall(twinkly.set_mode, ip, "off")
  if ok then
    print("Done: " .. tostring(result))
  else
    print("Error: " .. tostring(result))
  end
elseif cmd == "get" then
  print("Getting status from " .. ip .. "...")
  local mode = twinkly.get_mode(ip)
  print("Mode: " .. tostring(mode))
  
  local brightness = twinkly.get_brightness(ip)
  print("Brightness: " .. tostring(brightness))
  
  local color = twinkly.get_color(ip)
  if color then
    print("Color RGB: " .. tostring(color.red) .. "," .. tostring(color.green) .. "," .. tostring(color.blue))
  else
    print("Color: " .. tostring(color))
  end
elseif cmd == "brightness" then
  local level = tonumber(args[3])
  if not level then
    print("Error: brightness level must be a number 0-100")
    os.exit(1)
  end
  print("Setting brightness to " .. level .. " on " .. ip)
  local ok, result = pcall(twinkly.set_brightness, ip, level)
  if ok then
    print("Done: " .. tostring(result))
  else
    print("Error: " .. tostring(result))
  end
elseif cmd == "color" then
  local hue = tonumber(args[3]) or 0
  local sat = tonumber(args[4]) or 100
  local val = tonumber(args[5]) or 100
  print("Setting color HSV(" .. hue .. "," .. sat .. "," .. val .. ") on " .. ip)
  local ok, result = pcall(twinkly.set_color_hsv, ip, hue, sat, val)
  if ok then
    print("Done: " .. tostring(result))
  else
    print("Error: " .. tostring(result))
  end
elseif cmd == "rgb" then
  local red = tonumber(args[3]) or 255
  local green = tonumber(args[4]) or 0
  local blue = tonumber(args[5]) or 0
  print("Setting color RGB(" .. red .. "," .. green .. "," .. blue .. ") on " .. ip)
  local ok, result = pcall(twinkly.set_color_rgb, ip, red, green, blue)
  if ok then
    print("Done: " .. tostring(result))
  else
    print("Error: " .. tostring(result))
  end
else
  print("Unknown command: " .. cmd)
end
