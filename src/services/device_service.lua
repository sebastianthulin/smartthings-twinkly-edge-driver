-- Device Service Implementation  
-- Implements IDeviceService interface for Twinkly device operations

local class = require "vendor.30log"
local interfaces = require "interfaces"
local json = require "dkjson"
local socket = require "socket" -- for short sleep between reauth retries
local config = require "twinkly.config"

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

-- List available effects on device (both builtin and user-uploaded movies)
-- Based on official Twinkly REST API documentation  
function DeviceService:list_effects(ip, type)
  type = type or "all"  -- default to all effects
  
  local list = {}

  -- Get builtin effects using /xled/v1/led/effects endpoint
  if type == "all" or type == "builtin" then
    local ok, code, status, body = self:_make_authenticated_request(ip, config.get_endpoint("effects"), "GET")
    if ok then
      local decoded = json.decode(body)
      if decoded and decoded.effects_number and decoded.effects_number > 0 then
        self._logger:debug("Found " .. decoded.effects_number .. " builtin effects")
        
        -- Create effect entries from the response
        -- If unique_ids are available (firmware 2.5.6+), use them
        if decoded.unique_ids and type(decoded.unique_ids) == "table" then
          for i, unique_id in ipairs(decoded.unique_ids) do
            table.insert(list, {
              id = i - 1,  -- Effects are 0-indexed
              unique_id = unique_id,
              name = "Effect " .. (i - 1), -- Default name
              type = "builtin"
            })
          end
        else
          -- Fallback for older firmware - create numbered effects
          for i = 0, decoded.effects_number - 1 do
            table.insert(list, {
              id = i,
              name = "Effect " .. i,
              type = "builtin"
            })
          end
        end
      else
        self._logger:debug("No builtin effects found or invalid response for " .. ip)
      end
    else
      self._logger:warn("Failed to fetch builtin effects for " .. ip .. ": " .. tostring(status))
    end
  end

  -- Get user-uploaded movies using /xled/v1/movies endpoint (firmware 2.5.6+)
  if type == "all" or type == "user" then
    local ok, code, status, body = self:_make_authenticated_request(ip, config.get_endpoint("movies"), "GET")
    if ok then
      local decoded = json.decode(body)
      if decoded and decoded.movies and type(decoded.movies) == "table" then
        self._logger:debug("Found " .. #decoded.movies .. " uploaded movies")
        
        for _, movie in ipairs(decoded.movies) do
          table.insert(list, {
            id = movie.id,
            unique_id = movie.unique_id,
            name = movie.name or "Movie " .. tostring(movie.id),
            type = "user",
            -- Additional movie metadata
            descriptor_type = movie.descriptor_type,
            leds_per_frame = movie.leds_per_frame,
            frames_number = movie.frames_number,
            fps = movie.fps
          })
        end
      else
        self._logger:debug("No user movies found or invalid response for " .. ip)
      end
    else
      self._logger:debug("Failed to fetch user movies for " .. ip .. ": " .. tostring(status))
    end
  end

  return list
end

-- Activate a specific effect by ID
-- Based on official Twinkly REST API documentation
function DeviceService:set_effect(ip, effect_id, effect_type)
  if not effect_id then
    return nil, "Effect ID is required"
  end
  
  self._logger:debug("Setting effect " .. tostring(effect_id) .. " (" .. tostring(effect_type or "unknown") .. ") on " .. tostring(ip))

  -- Set appropriate mode and endpoint based on effect type
  if effect_type == "builtin" then
    -- For builtin effects: set mode to "effect" and use effects/current endpoint
    local ok, err = self:set_mode(ip, "effect")
    if not ok then 
      return nil, err 
    end

    local payload = { effect_id = effect_id }
    local ok2, code, status, body = self:_make_authenticated_request(
      ip, config.get_endpoint("effects_current"), "POST", payload)
    
    if ok2 then
      self._logger:debug("Successfully set builtin effect " .. effect_id)
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
      ip, config.get_endpoint("movies_current"), "POST", payload)
    
    if ok2 then
      self._logger:debug("Successfully set user movie " .. effect_id)
      return true, body
    else
      return nil, "Failed to set user movie: " .. tostring(status)
    end
    
  else
    -- Legacy mode: try both approaches for backward compatibility
    self._logger:debug("Effect type not specified, trying both builtin and movie endpoints")
    
    -- Try builtin effect first
    local ok_effect = self:set_mode(ip, "effect")
    if ok_effect then
      local payload = { effect_id = effect_id }
      local ok2, code, status, body = self:_make_authenticated_request(
        ip, config.get_endpoint("effects_current"), "POST", payload)
      
      if ok2 then
        self._logger:debug("Successfully set as builtin effect " .. effect_id)
        return true, body
      end
    end
    
    -- Try as movie if builtin effect failed
    local ok_movie = self:set_mode(ip, "movie")
    if ok_movie then
      local payload = { id = effect_id }
      local ok3, code2, status2, body2 = self:_make_authenticated_request(
        ip, config.get_endpoint("movies_current"), "POST", payload)
      
      if ok3 then
        self._logger:debug("Successfully set as user movie " .. effect_id)
        return true, body2
      end
    end
    
    return nil, "Failed to set effect: neither builtin effect nor user movie worked"
  end
end

-- Get current effect information  
-- Based on official Twinkly REST API documentation
function DeviceService:get_effect(ip)
  self._logger:debug("Getting current effect for " .. tostring(ip))
  
  -- Get current mode first to determine what type of content is active
  local mode_data = self:get_mode(ip)
  if not mode_data then
    return nil, "Failed to get device mode"
  end
  
  local mode = mode_data.mode or mode_data
  
  if mode == "effect" then
    -- Device is in effect mode - check current effect
    local ok, code, status, body = self:_make_authenticated_request(
      ip, config.get_endpoint("effects_current"), "GET")
    
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
      ip, config.get_endpoint("movies_current"), "GET")
    
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