-- Login Feature Implementation
-- Handles the initial login process with challenge-response authentication

local class = require "vendor.30log"
local json = require "dkjson"

local LoginFeature = class("LoginFeature")

function LoginFeature:init(http_client, logger, utils)
  self._http_client = http_client
  self._logger = logger
  self._utils = utils
end

-- Perform full login + verify handshake  
function LoginFeature:login(ip)
  if not ip then 
    return nil, "No IP provided" 
  end

  self._logger:info("[LoginFeature] Logging in to " .. ip)
  
  local challenge = self._utils.random_base64(16)
  local login_body = json.encode({ challenge = challenge })

  -- Step 1: POST /login
  local response = self._http_client:post(
    "http://" .. ip .. "/xled/v1/login",
    login_body
  )

  if not response.success or response.status_code ~= 200 then
    self._logger:warn("[LoginFeature] Failed to login to " .. tostring(ip) .. 
                      ": " .. tostring(response.status_line))
    return nil, "Login failed: " .. tostring(response.status_line)
  end

  self._logger:debug("[LoginFeature] Login response: " .. tostring(response.body))
  
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

  self._logger:info("[LoginFeature] Logged in successfully for " .. ip)
  return token
end

return LoginFeature
