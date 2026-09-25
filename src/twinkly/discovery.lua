local socket = require "cosock".socket
local api = require "twinkly.api"

local M = {}
local pending_ips = {}
local pending_creates = {}
local CREATE_RETRY_SECONDS = 30

local function network_id(info)
  if type(info) ~= "table" or info.product_name ~= "Twinkly" then return nil end
  local mac = type(info.mac) == "string" and info.mac:lower():gsub("[^0-9a-f]", "") or ""
  if #mac ~= 12 then return nil end
  return "twinkly-" .. mac
end

local function is_legacy_placeholder(dev)
  local suffix = type(dev.device_network_id) == "string" and
    dev.device_network_id:match("^twinkly%-(%d+)$")
  -- Old placeholders used os.time(), whereas MAC-based IDs have 12 hex digits.
  return suffix ~= nil and #suffix >= 9 and #suffix <= 11
end

local function at_least(version, minimum)
  if type(version) ~= "string" then return false end
  local major, minor, patch = version:match("^(%d+)%.(%d+)%.(%d+)")
  if not major then return false end
  local a = { tonumber(major), tonumber(minor), tonumber(patch) }
  for i = 1, 3 do
    if a[i] > minimum[i] then return true end
    if a[i] < minimum[i] then return false end
  end
  return true
end

local function profile_for(info, version)
  if at_least(version, { 2, 7, 1 }) then return "twinkly-color-light" end
  local family = info.fw_family or "D"
  local brightness_minimum = {
    D = { 2, 3, 5 }, F = { 2, 4, 2 }, G = { 2, 4, 21 },
  }
  if brightness_minimum[family] and at_least(version, brightness_minimum[family]) then
    return "twinkly-dimmer"
  end
  return "twinkly-switch"
end

function M.scan(driver, create_devices)
  local udp, open_err = socket.udp()
  if not udp then return nil, open_err end
  udp:settimeout(2)
  udp:setoption("broadcast", true)
  local sent, err = udp:sendto("\1discover", "255.255.255.255", 5555)
  if not sent then udp:close(); return nil, err end
  local seen = {}
  local seen_ids = {}
  local deadline = socket.gettime() + 2
  while socket.gettime() < deadline do
    udp:settimeout(math.max(0, deadline - socket.gettime()))
    local data, ip = udp:receivefrom()
    if not data then break end
    local signature = #data >= 7 and data:sub(5, 6)
    if (signature == "OK" or signature == "yu") and not seen[ip] then
      seen[ip] = true
      local info = api.gestalt(ip)
      local id = network_id(info)
      if id then
        pending_ips[id] = ip
        local existing
        for _, dev in pairs(driver:get_devices()) do
          if dev.device_network_id == id or
            (is_legacy_placeholder(dev) and (dev:get_field("ipAddress") == ip or
              (dev.preferences and dev.preferences.ipAddress == ip))) then
            existing = dev
            break
          end
        end
        if existing then
          pending_creates[id] = nil
          existing:set_field("ipAddress", ip, { persist = true })
        elseif create_devices ~= false and not seen_ids[id] then
          seen_ids[id] = true
          local now = socket.gettime()
          local pending = pending_creates[id]
          if not pending or pending.driver ~= driver or now < pending.at or
            now - pending.at >= CREATE_RETRY_SECONDS then
            local version = api.firmware_version(ip)
            driver:try_create_device({
              type = "LAN", device_network_id = id,
              label = info.device_name or "Twinkly", profile = profile_for(info, version),
              manufacturer = "Twinkly", model = info.product_code or "Twinkly",
            })
            pending_creates[id] = { driver = driver, at = now }
          end
        end
      end
    end
  end
  udp:close()
  return true
end

M.network_id = network_id
M.profile_for = profile_for
function M.pending_ip(id)
  return pending_ips[id]
end
return M
