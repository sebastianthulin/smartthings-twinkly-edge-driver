-- Token Manager Feature Implementation
-- Handles token caching, validation, and session management

local class = require "vendor.30log"

local TokenManager = class("TokenManager")

function TokenManager:init(http_client, logger)
  self._http_client = http_client
  self._logger = logger
  self._sessions = {} -- In-memory token storage
end

-- Clear a cached token for given IP
function TokenManager:clear_token(ip)
  if self._sessions[ip] then
    self._logger:debug("[TokenManager] Clearing token for " .. tostring(ip))
    self._sessions[ip] = nil
  end
end

-- Validate existing token with a quick /verify call
function TokenManager:validate_token(ip, token)
  if not token then
    return false
  end

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

  return verify_response.success and verify_response.status_code == 200
end

-- Cache a token for an IP
function TokenManager:cache_token(ip, token)
  self._sessions[ip] = token
  self._logger:debug("[TokenManager] Cached token for " .. tostring(ip))
end

-- Get cached token for IP
function TokenManager:get_cached_token(ip)
  return self._sessions[ip]
end

-- Check if we have a cached token for IP (doesn't validate)
function TokenManager:has_cached_token(ip)
  return self._sessions[ip] ~= nil
end

-- Get all cached sessions (for debugging/monitoring)
function TokenManager:get_cached_sessions()
  local sessions = {}
  for ip, token in pairs(self._sessions) do
    sessions[ip] = {
      has_token = token ~= nil,
      token_length = token and #token or 0
    }
  end
  return sessions
end

return TokenManager
