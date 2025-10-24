-- Verification Feature Implementation
-- Handles token verification and validation

local class = require "vendor.30log"

local VerificationFeature = class("VerificationFeature")

function VerificationFeature:init(http_client, logger)
  self._http_client = http_client
  self._logger = logger
end

-- Verify a token with the device
function VerificationFeature:verify_token(ip, token)
  if not token then
    return false, "No token provided"
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
  self._logger:debug(string.format("[TokenDebug] Verification response for %s: success=%s code=%s body=%s", ip, tostring(verify_response.success), tostring(verify_response.status_code), tostring(verify_response.body)))
  if verify_response.success and verify_response.status_code == 200 then
    self._logger:debug("[VerificationFeature] Token valid for " .. ip)
    return true
  else
    self._logger:warn("[VerificationFeature] Token invalid for " .. ip)
    return false, "Token verification failed"
  end
end

return VerificationFeature
