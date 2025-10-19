-- Authentication Service Implementation
-- Implements IAuthenticationService interface with token management

local class = require "vendor.30log"
local interfaces = require "interfaces"
local json = require "dkjson"

local AuthenticationService = interfaces.IAuthenticationService:extend("AuthenticationService")

function AuthenticationService:init(http_client, logger, utils)
  self._http_client = http_client
  self._logger = logger
  self._utils = utils
  self._sessions = {} -- In-memory token storage
end

-- Clear a cached token for given IP
function AuthenticationService:clear_token(ip)
  if self._sessions[ip] then
    self._logger:debug("[AuthService] Clearing token for " .. tostring(ip))
    self._sessions[ip] = nil
  end
end

-- Perform full login + verify handshake  
function AuthenticationService:login(ip)
  if not ip then 
    return nil, "No IP provided" 
  end

  self._logger:info("[AuthService] Logging in to " .. ip)
  
  local challenge = self._utils.random_base64(16)
  local login_body = json.encode({ challenge = challenge })

  -- Step 1: POST /login
  local response = self._http_client:post(
    "http://" .. ip .. "/xled/v1/login",
    login_body
  )

  if not response.success or response.status_code ~= 200 then
    self._logger:warn("[AuthService] Failed to login to " .. tostring(ip) .. 
                      ": " .. tostring(response.status_line))
    return nil, "Login failed: " .. tostring(response.status_line)
  end

  self._logger:debug("[AuthService] Login response: " .. tostring(response.body))
  
  local decoded = json.decode(response.body)
  if not decoded or not decoded.authentication_token or not decoded["challenge-response"] then
    return nil, "Login response missing fields. Body: " .. response.body
  end

  local token = decoded.authentication_token
  local expected_response = decoded["challenge-response"]

  -- Step 2: POST /verify (verify handshake)
  local verify_body = json.encode({ ["challenge-response"] = expected_response })
  local verify_response = self._http_client:request({
    url = "http://" .. ip .. "/xled/v1/verify",
    method = "POST",
    headers = {
      ["X-Auth-Token"] = token,
      ["Content-Type"] = "application/json",
      ["Content-Length"] = tostring(#verify_body)
    },
    body = verify_body
  })

  if not verify_response.success or verify_response.status_code ~= 200 then
    return nil, "Verification failed: " .. tostring(verify_response.status_line)
  end

  -- Cache the valid token
  self._sessions[ip] = token
  self._logger:info("[AuthService] Logged in successfully for " .. ip)
  return token
end

-- Ensure valid token (auto re-login if invalid)
function AuthenticationService:ensure_token(ip)
  local token = self._sessions[ip]

  -- Validate existing token with a quick /verify call
  if token then
    local verify_response = self._http_client:request({
      url = "http://" .. ip .. "/xled/v1/verify",
      method = "POST",
      headers = {
        ["X-Auth-Token"] = token,
        ["Content-Type"] = "application/json",
        ["Content-Length"] = "2"
      },
      body = "{}"
    })

    if verify_response.success and verify_response.status_code == 200 then
      self._logger:debug("[AuthService] Existing token still valid for " .. ip)
      return token
    else
      self._logger:warn("[AuthService] Token invalid for " .. ip .. ", clearing...")
      self._sessions[ip] = nil
    end
  end

  -- No valid token exists, perform fresh login
  self._logger:debug("[AuthService] Performing fresh login for " .. ip)
  return self:login(ip)
end

-- Check if we have a cached token for IP (doesn't validate)
function AuthenticationService:has_cached_token(ip)
  return self._sessions[ip] ~= nil
end

-- Get all cached sessions (for debugging/monitoring)
function AuthenticationService:get_cached_sessions()
  local sessions = {}
  for ip, token in pairs(self._sessions) do
    sessions[ip] = {
      has_token = token ~= nil,
      token_length = token and #token or 0
    }
  end
  return sessions
end

return AuthenticationService