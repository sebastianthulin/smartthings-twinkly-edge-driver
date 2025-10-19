-- Device Service Implementation  
-- Implements IDeviceService interface for Twinkly device operations

local class = require "vendor.30log"
local interfaces = require "interfaces"
local json = require "dkjson"
local socket = require "socket" -- for short sleep between reauth retries
local config = require "twinkly.config"

-- Helper function to format raw response logging
local function log_raw_response(logger, url, method, request_headers, request_body, response)
  -- Check if raw responses are enabled
  local test_utils_ok, test_utils = pcall(require, "test-utils")
  local test_config = test_utils_ok and test_utils.load_config() or {}
  
  if not test_config.rawResponses then
    return -- Raw responses disabled
  end
  
  local timestamp = os.date("%Y-%m-%d_%H-%M-%S")
  local log_data = {
    timestamp = os.date("%Y-%m-%d %H:%M:%S"),
    request = {
      method = method,
      url = url,
      headers = {},
      body = request_body
    },
    response = {
      status_code = response.status_code,
      status_line = response.status_line,
      headers = response.headers or {},
      body = response.body
    }
  }
  
  -- Copy headers but hide sensitive tokens for file logging
  if request_headers then
    for k, v in pairs(request_headers) do
      log_data.request.headers[k] = k:lower():match("token") and "***HIDDEN***" or v
    end
  end
  
  -- Create logs directory if it doesn't exist
  local logs_dir = "test-logs"
  os.execute("mkdir -p " .. logs_dir)
  
  -- Generate unique log filename
  local endpoint_name = url:match("/([^/]+)$") or "unknown"
  local log_filename = string.format("%s/api_%s_%s_%s.log", 
    logs_dir, method:lower(), endpoint_name, timestamp)
  
  -- Write detailed log to file
  local log_file = io.open(log_filename, "w")
  if log_file then
    log_file:write("================================================================================\n")
    log_file:write("🌐 RAW API REQUEST/RESPONSE LOG\n")
    log_file:write("================================================================================\n")
    log_file:write("Timestamp: " .. log_data.timestamp .. "\n\n")
    
    -- Request section
    log_file:write("📤 REQUEST:\n")
    log_file:write("   Method: " .. tostring(log_data.request.method) .. "\n")
    log_file:write("   URL: " .. tostring(log_data.request.url) .. "\n")
    
    -- Request headers
    log_file:write("   Headers:\n")
    for k, v in pairs(log_data.request.headers) do
      log_file:write("     " .. k .. ": " .. tostring(v) .. "\n")
    end
    
    -- Request body
    if log_data.request.body then
      log_file:write("   Body:\n")
      -- Try to format JSON if it's valid JSON
      local formatted_body = log_data.request.body
      if log_data.request.body:match("^%s*{") then
        local parsed = json.decode(log_data.request.body)
        if parsed then
          formatted_body = json.encode(parsed, {indent = true})
        end
      end
      log_file:write("     " .. formatted_body:gsub("\n", "\n     ") .. "\n")
    else
      log_file:write("   Body: (none)\n")
    end
    
    -- Response section
    log_file:write("\n📥 RESPONSE:\n")
    log_file:write("   Status: " .. tostring(log_data.response.status_code) .. " " .. tostring(log_data.response.status_line or "") .. "\n")
    
    -- Response headers
    log_file:write("   Headers:\n")
    for k, v in pairs(log_data.response.headers) do
      log_file:write("     " .. k .. ": " .. tostring(v) .. "\n")
    end
    
    -- Response body
    log_file:write("   Body:\n")
    if log_data.response.body and log_data.response.body ~= "" then
      -- Try to format JSON if it's valid JSON
      local formatted_body = log_data.response.body
      if log_data.response.body:match("^%s*{") then
        local parsed = json.decode(log_data.response.body)
        if parsed then
          formatted_body = json.encode(parsed, {indent = true})
        end
      end
      log_file:write("     " .. formatted_body:gsub("\n", "\n     ") .. "\n")
    else
      log_file:write("     (empty)\n")
    end
    
    log_file:write("================================================================================\n")
    log_file:close()
    
    -- Update logs index file
    local index_file = io.open(logs_dir .. "/index.txt", "a")
    if index_file then
      index_file:write(string.format("%s | %s %s | %s\n", 
        log_data.timestamp, method, endpoint_name, log_filename))
      index_file:close()
    end
    
    -- Notify about log file creation
    print("💾 Raw API data logged to: " .. log_filename)
  else
    logger:warn("Failed to create log file: " .. log_filename)
  end
  
  -- Also display to console (existing functionality)
  print("\n" .. string.rep("=", 80))
  print("🌐 RAW API REQUEST/RESPONSE")
  print(string.rep("=", 80))
  
  -- Request information
  print("📤 REQUEST:")
  print("   Method: " .. tostring(method))
  print("   URL: " .. tostring(url))
  
  -- Request headers
  if request_headers then
    print("   Headers:")
    for k, v in pairs(request_headers) do
      -- Hide sensitive tokens
      local display_value = k:lower():match("token") and "***HIDDEN***" or v
      print("     " .. k .. ": " .. tostring(display_value))
    end
  end
  
  -- Request body
  if request_body then
    print("   Body:")
    -- Try to format JSON if it's valid JSON
    local formatted_body = request_body
    if request_body:match("^%s*{") then
      local parsed = json.decode(request_body)
      if parsed then
        formatted_body = json.encode(parsed, {indent = true})
      end
    end
    print("     " .. formatted_body:gsub("\n", "\n     "))
  else
    print("   Body: (none)")
  end
  
  print("\n📥 RESPONSE:")
  print("   Status: " .. tostring(response.status_code) .. " " .. tostring(response.status_line or ""))
  
  -- Response headers
  if response.headers then
    print("   Headers:")
    for k, v in pairs(response.headers) do
      print("     " .. k .. ": " .. tostring(v))
    end
  end
  
  -- Response body
  print("   Body:")
  if response.body and response.body ~= "" then
    -- Try to format JSON if it's valid JSON
    local formatted_body = response.body
    if response.body:match("^%s*{") then
      local parsed = json.decode(response.body)
      if parsed then
        formatted_body = json.encode(parsed, {indent = true})
      end
    end
    print("     " .. formatted_body:gsub("\n", "\n     "))
  else
    print("     (empty)")
  end
  
  print(string.rep("=", 80) .. "\n")
end

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

  local full_url = "http://" .. ip .. endpoint
  local response = self._http_client:request({
    url = full_url,
    method = method,
    headers = headers,
    body = body
  })

  -- Log raw response if enabled
  log_raw_response(self._logger, full_url, method, headers, body, response)
  
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

-- List available effects on device - firmware 2.9.1+ only
function DeviceService:list_effects(ip, effect_type)
  effect_type = effect_type or "all"  -- default to all effects
  
  local list = {}

  -- Get builtin effects (firmware 2.9.1+ only)
  if effect_type == "all" or effect_type == "builtin" then
    local ok, code, status, body = self:_make_authenticated_request(ip, "/xled/v1/led/effects", "GET")
    if ok then
      local decoded = json.decode(body)
      if decoded and decoded.unique_ids and type(decoded.unique_ids) == "table" then
        for i, unique_id in ipairs(decoded.unique_ids) do
          table.insert(list, {
            id = i,
            name = "Effect " .. i,
            type = "builtin",
            unique_id = unique_id
          })
        end
      elseif decoded and decoded.effects_number and type(decoded.effects_number) == "number" then
        -- Create effects based on effects_number
        for i = 1, decoded.effects_number do
          table.insert(list, {
            id = i,
            name = "Effect " .. i,
            type = "builtin",
            unique_id = string.format("%08x-%04x-%04x-%04x-%012x", i, 0, 0, 0, i)
          })
        end
      end
    else
      self._logger:warn("Failed to fetch builtin effects for " .. ip .. ": " .. tostring(status))
    end
  end

  -- Get user movies (firmware 2.9.1+ only)
  if effect_type == "all" or effect_type == "user" then
    local ok, code, status, body = self:_make_authenticated_request(ip, "/xled/v1/movies", "GET")
    if ok then
      local decoded = json.decode(body)
      if decoded and decoded.movies then
        for _, v in ipairs(decoded.movies) do
          v.type = "user"
          table.insert(list, v)
        end
      end
    else
      self._logger:warn("Failed to fetch user movies for " .. ip .. ": " .. tostring(status))
    end
  end

  return list
end

-- Activate a specific effect by ID - firmware 2.9.1+ only
function DeviceService:set_effect(ip, effect_id, effect_type)
  if not effect_id then
    return nil, "Effect ID is required"
  end
  
  self._logger:debug("Setting effect " .. tostring(effect_id) .. " (" .. tostring(effect_type or "builtin") .. ") on " .. tostring(ip))

  -- Default to builtin for firmware 2.9.1+
  effect_type = effect_type or "builtin"

  if effect_type == "builtin" then
    -- For builtin effects: set mode to "effect" and use effects/current endpoint
    local ok, err = self:set_mode(ip, "effect")
    if not ok then 
      return nil, err 
    end

    local payload = { effect_id = effect_id }
    local ok2, code, status, body = self:_make_authenticated_request(
      ip, "/xled/v1/led/effects/current", "POST", payload)
    
    if ok2 then
      return true, body
    else
      return nil, "Failed to set builtin effect: " .. tostring(status)
    end
    
  elseif effect_type == "user" then
    -- For user movies: set mode to "movie" and use movies/current endpoint
    local ok, err = self:set_mode(ip, "movie")
    if not ok then 
      return nil, err 
    end

    local payload = { id = effect_id }
    local ok2, code, status, body = self:_make_authenticated_request(
      ip, "/xled/v1/led/movies/current", "POST", payload)
    
    if ok2 then
      return true, body
    else
      return nil, "Failed to set user movie: " .. tostring(status)
    end
  else
    return nil, "Unknown effect type: " .. tostring(effect_type)
  end
end

-- Get current effect information - firmware 2.9.1+ only
function DeviceService:get_effect(ip)
  local mode = self:get_mode(ip)
  if not mode then
    return nil, "Unable to get device mode"
  end
  
  if mode == "effect" then
    -- Device is in effect mode - check current effect
    local ok, code, status, body = self:_make_authenticated_request(
      ip, "/xled/v1/led/effects/current", "GET")
    
    if ok then
      local decoded = json.decode(body)
      if decoded and decoded.effect_id ~= nil then
        return {
          id = decoded.effect_id,
          unique_id = decoded.unique_id,
          name = "Effect " .. decoded.effect_id,
          type = "builtin"
        }
      end
    else
      self._logger:debug("Failed to get current effect: " .. tostring(status))
    end
    
  elseif mode == "movie" then
    -- Device is in movie mode - check current movie
    local ok, code, status, body = self:_make_authenticated_request(
      ip, "/xled/v1/led/movies/current", "GET")
    
    if ok then
      local decoded = json.decode(body)
      if decoded and decoded.id ~= nil then
        return {
          id = decoded.id,
          unique_id = decoded.unique_id,
          name = decoded.name or ("Movie " .. decoded.id),
          type = "user"
        }
      end
    else
      self._logger:debug("Failed to get current movie: " .. tostring(status))
    end
    
  else
    return nil, "Device is not in effect or movie mode (current mode: " .. tostring(mode) .. ")"
  end
  
  return nil, "No current effect information available"
end

return DeviceService