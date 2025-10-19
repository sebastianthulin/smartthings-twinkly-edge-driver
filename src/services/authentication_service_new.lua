-- Authentication Service Implementation
-- Orchestrates authentication features using dependency injection

local class = require "vendor.30log"
local interfaces = require "interfaces"
local LoginFeature = require "features.authentication.login"
local TokenManager = require "features.authentication.token_manager"
local VerificationFeature = require "features.authentication.verification"

local AuthenticationService = interfaces.IAuthenticationService:extend("AuthenticationService")

function AuthenticationService:init(http_client, logger, utils)
  self._login_feature = LoginFeature:new(http_client, logger, utils)
  self._token_manager = TokenManager:new(http_client, logger)
  self._verification_feature = VerificationFeature:new(http_client, logger)
end

-- Clear a cached token for given IP
function AuthenticationService:clear_token(ip)
  return self._token_manager:clear_token(ip)
end

-- Perform full login + verify handshake  
function AuthenticationService:login(ip)
  local token, err = self._login_feature:login(ip)
  if token then
    self._token_manager:cache_token(ip, token)
  end
  return token, err
end

-- Ensure valid token (auto re-login if invalid)
function AuthenticationService:ensure_token(ip)
  local token = self._token_manager:get_cached_token(ip)

  -- Validate existing token
  if token then
    local is_valid = self._verification_feature:verify_token(ip, token)
    if is_valid then
      self._logger:debug("[AuthService] Existing token still valid for " .. ip)
      return token
    else
      self._logger:warn("[AuthService] Token invalid for " .. ip .. ", clearing...")
      self._token_manager:clear_token(ip)
    end
  end

  -- No valid token exists, perform fresh login
  self._logger:debug("[AuthService] Performing fresh login for " .. ip)
  return self:login(ip)
end

-- Check if we have a cached token for IP (doesn't validate)
function AuthenticationService:has_cached_token(ip)
  return self._token_manager:has_cached_token(ip)
end

-- Get all cached sessions (for debugging/monitoring)
function AuthenticationService:get_cached_sessions()
  return self._token_manager:get_cached_sessions()
end

return AuthenticationService
