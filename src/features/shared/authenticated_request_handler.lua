-- Authenticated Request Handler
-- Provides token retry logic for all device control features

local class = require "vendor.30log"
local json = require "dkjson"
local socket = require "socket"

local AuthenticatedRequestHandler = class("AuthenticatedRequestHandler")

function AuthenticatedRequestHandler:init(http_client, auth_service, logger)
  self._http_client = http_client
  self._auth_service = auth_service
  self._logger = logger
end

-- Make authenticated request with auto-retry logic
function AuthenticatedRequestHandler:make_request(ip, endpoint, method, payload)
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

  self._logger:debug(string.format("[AuthenticatedRequest %s %s] code=%s body=%s", 
    method, endpoint, tostring(response.status_code), tostring(response.body)))

  -- Token expired or taken by Twinkly app - retry once
  if response.status_code == 401 or (response.body and response.body:match("Invalid Token")) then
    self._logger:warn(string.format("[AuthenticatedRequest %s] Token invalid — refreshing session for %s", 
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
    
    self._logger:debug(string.format("[AuthenticatedRequest RETRY %s %s] code=%s body=%s", 
      method, endpoint, tostring(response.status_code), tostring(response.body)))
    
    -- Give up after retry if still failing
    if response.status_code == 401 or (response.body and response.body:match("Invalid Token")) then
      self._logger:warn(string.format("[AuthenticatedRequest %s] Giving up after retry for %s", endpoint, ip))
      return nil, "Invalid Token after retry"
    end
  end

  if not response.success or response.status_code ~= 200 then
    self._logger:warn(string.format("[AuthenticatedRequest %s %s] Failed: code=%s body=%s", 
      method, endpoint, tostring(response.status_code), tostring(response.body)))
    return nil, string.format("Request failed: %s (code=%s)", endpoint, tostring(response.status_code))
  end

  return response.success, response.status_code, response.status_line, response.body
end

return AuthenticatedRequestHandler
