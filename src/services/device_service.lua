-- Device Service Implementation  
-- Implements IDeviceService interface for Twinkly device operations

local class = require "vendor.30log"
local interfaces = require "interfaces"
local json = require "dkjson"
local socket = require "socket" -- for short sleep between reauth retries

local DeviceService = interfaces.IDeviceService:extend("DeviceService")

function DeviceService:init(http_client, auth_service, color_converter, logger)
  self._http_client = http_client
  self._auth_service = auth_service
  self._color_converter = color_converter  
  self._logger = logger
end

-- Internal helper for making authenticated requests with auto-retry
function DeviceService:_make_authenticated_request(ip, endpoint, method, payload)
  method = method or "GET"
  local body = payload and json.encode(payload) or nil
  
  local token, err = self._auth_service:ensure_token(ip)
  if not token then
    self._logger:error("No token for " .. tostring(ip) .. ": " .. tostring(err))
    return nil, err
  end

  local headers = { ["X-Auth-Token"] = token }
  if body then
    headers["Content-Type"] = "application/json"
    headers["Content-Length"] = tostring(#body)
  end

  local response = self._http_client:request({
    url = "http://" .. ip .. endpoint,
    method = method,
    headers = headers,
    body = body
  })

  self._logger:debug(string.format("[DeviceService %s %s] code=%s body=%s", 
    method, endpoint, tostring(response.status_code), tostring(response.body)))

  -- Token expired or taken by Twinkly app - retry once
  if response.status_code == 401 or (response.body and response.body:match("Invalid Token")) then
    self._logger:warn(string.format("[DeviceService %s] Token invalid — refreshing session for %s", 
      endpoint, ip))
    
    self._auth_service:clear_token(ip)
    socket.sleep(0.4) -- Brief delay for token refresh
    
    local new_token, nerr = self._auth_service:ensure_token(ip)
    if not new_token then
      self._logger:error("Re-login failed for " .. tostring(ip) .. ": " .. tostring(nerr))
      return nil, nerr
    end
    
    headers["X-Auth-Token"] = new_token
    response = self._http_client:request({
      url = "http://" .. ip .. endpoint,
      method = method,
      headers = headers,
      body = body
    })
    
    self._logger:debug(string.format("[DeviceService RETRY %s %s] code=%s body=%s", 
      method, endpoint, tostring(response.status_code), tostring(response.body)))
    
    -- Give up after retry if still failing
    if response.status_code == 401 or (response.body and response.body:match("Invalid Token")) then
      self._logger:warn(string.format("[DeviceService %s] Giving up after retry for %s", endpoint, ip))
      return nil, "Invalid Token after retry"
    end
  end

  if not response.success or response.status_code ~= 200 then
    self._logger:warn(string.format("[DeviceService %s %s] Failed: code=%s body=%s", 
      method, endpoint, tostring(response.status_code), tostring(response.body)))
    return nil, string.format("Request failed: %s (code=%s)", endpoint, tostring(response.status_code))
  end

  return response.success, response.status_code, response.status_line, response.body
end

-- Set device mode (on/off/movie/color/etc)
function DeviceService:set_mode(ip, mode)
  self._logger:debug("Setting mode=" .. tostring(mode) .. " for " .. tostring(ip))
  
  local ok, code, status, body = self:_make_authenticated_request(
    ip, "/xled/v1/led/mode", "POST", { mode = mode })
  
  if not ok then 
    return nil, status 
  end
  return true, body
end

-- Get current device mode
function DeviceService:get_mode(ip)
  self._logger:debug("[DeviceService] Getting mode for IP: " .. tostring(ip))
  
  local ok, code, status, body = self:_make_authenticated_request(
    ip, "/xled/v1/led/mode", "GET")
  
  if not ok then 
    return nil, "Failed to get mode: " .. tostring(status) .. " Body: " .. (body or "")
  end

  local decoded, _, jerr = json.decode(body)
  if not decoded then
    return nil, "Invalid JSON: " .. tostring(jerr) .. " Body: " .. body
  end

  local raw_mode = decoded.mode
  self._logger:debug("[DeviceService] Raw mode: " .. tostring(raw_mode))
  return raw_mode
end

-- Set brightness level (0-100)
function DeviceService:set_brightness(ip, level)
  level = math.max(0, math.min(100, level or 0))
  
  local ok, code, status, body = self:_make_authenticated_request(
    ip, "/xled/v1/led/out/brightness", "POST", { value = level })
  
  if not ok then 
    return nil, status 
  end
  return true, body
end

-- Get current brightness level
function DeviceService:get_brightness(ip)
  local ok, code, status, body = self:_make_authenticated_request(
    ip, "/xled/v1/led/out/brightness", "GET")
  
  if not ok then 
    return nil 
  end
  
  local decoded = json.decode(body)
  return decoded and decoded.value or 0
end

-- Set RGB color
function DeviceService:set_color_rgb(ip, red, green, blue)
  -- Validate input
  if not self._color_converter:validate_rgb(red, green, blue) then
    return nil, "Invalid RGB values"
  end
  
  self._logger:debug(string.format("Setting RGB(%d,%d,%d) -> %s", red, green, blue, ip))
  
  -- First set mode to color
  local ok, err = self:set_mode(ip, "color")
  if not ok then 
    return nil, err 
  end

  local payload = { red = red, green = green, blue = blue }
  local ok2, code, status, body = self:_make_authenticated_request(
    ip, "/xled/v1/led/color", "POST", payload)
  
  if not ok2 then 
    return nil, status 
  end
  return true, body
end

-- Set HSV color (converts to RGB internally)
function DeviceService:set_color_hsv(ip, hue, saturation, value)
  -- Normalize inputs
  saturation = (saturation or 0) / 100  -- Convert percentage to 0-1
  value = (value or 100) / 100          -- Convert percentage to 0-1  
  hue = hue or 0                        -- Hue stays 0-360
  
  -- Validate normalized values
  if not self._color_converter:validate_hsv(hue, saturation, value) then
    return nil, "Invalid HSV values"
  end
  
  local r, g, b = self._color_converter:hsv_to_rgb(hue, saturation, value)
  return self:set_color_rgb(ip, r, g, b)
end

-- Get current color
function DeviceService:get_color(ip)
  local ok, code, status, body = self:_make_authenticated_request(
    ip, "/xled/v1/led/color", "GET")
  
  if not ok then 
    return nil 
  end
  
  local decoded = json.decode(body)
  if decoded and decoded.red and decoded.green and decoded.blue then
    return {
      red = decoded.red,
      green = decoded.green, 
      blue = decoded.blue
    }
  end
  
  return nil
end

return DeviceService