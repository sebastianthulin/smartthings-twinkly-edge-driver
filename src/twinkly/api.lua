-- Small, bounded client for the Twinkly local HTTP API.
local json = require "dkjson"
local ltn12 = require "ltn12"
local socket = require "cosock".socket
local http = require "cosock".asyncify("socket.http")
local utils = require "twinkly.utils"

local M = {}
local tokens = {}
local TIMEOUT = 3
local CALL_BUDGET = 8
local MAX_RESPONSE_BYTES = 262144

local function bounded_socket(deadline)
  local conn = socket.tcp()
  local proxy = {}
  local function set_remaining(requested)
    local remaining = deadline - socket.gettime()
    if remaining <= 0 then return nil, "Request deadline exceeded" end
    return conn:settimeout(math.min(TIMEOUT, requested or TIMEOUT, remaining))
  end
  function proxy:settimeout(requested)
    return set_remaining(requested)
  end
  for _, name in ipairs({ "connect", "send", "receive" }) do
    proxy[name] = function(_, ...)
      local ok, err = set_remaining()
      if not ok then return nil, err end
      return conn[name](conn, ...)
    end
  end
  return setmetatable(proxy, { __index = function(_, name)
    local value = conn[name]
    if type(value) == "function" then
      return function(_, ...) return value(conn, ...) end
    end
    return value
  end })
end

local function request(ip, path, method, payload, token, deadline)
  deadline = deadline or socket.gettime() + TIMEOUT
  if socket.gettime() >= deadline then return nil, "Request deadline exceeded" end
  local chunks = {}
  local response_bytes = 0
  local oversized = false
  local body = payload and json.encode(payload) or nil
  local headers = { ["Connection"] = "close" }
  if token then headers["X-Auth-Token"] = token end
  if body then
    headers["Content-Type"] = "application/json"
    headers["Content-Length"] = tostring(#body)
  end
  local succeeded, ok, code = pcall(http.request, {
    url = "http://" .. ip .. path,
    method = method,
    headers = headers,
    source = body and ltn12.source.string(body) or nil,
    sink = function(chunk)
      if chunk then
        response_bytes = response_bytes + #chunk
        if response_bytes > MAX_RESPONSE_BYTES then
          oversized = true
          return nil, "Response too large"
        end
        chunks[#chunks + 1] = chunk
      end
      return 1
    end,
    create = function() return bounded_socket(deadline) end,
  })
  if not succeeded then return nil, tostring(ok) end
  if socket.gettime() > deadline then return nil, "Request deadline exceeded" end
  if oversized then return nil, "Response too large" end
  if not ok then return nil, tostring(code) end
  if code ~= 200 then return nil, "HTTP " .. tostring(code), code end
  local decoded = json.decode(table.concat(chunks))
  if type(decoded) ~= "table" then return nil, "Invalid JSON response" end
  if decoded.code ~= 1000 then return nil, "Twinkly code " .. tostring(decoded.code), decoded.code end
  return decoded
end

local function login(ip, deadline)
  local response, err = request(ip, "/xled/v1/login", "POST", {
    challenge = utils.random_base64(32),
  }, nil, deadline)
  if not response then return nil, err end
  if not response.authentication_token or not response["challenge-response"] then
    return nil, "Incomplete login response"
  end
  local token = response.authentication_token
  local verified, verify_err = request(ip, "/xled/v1/verify", "POST", {
    ["challenge-response"] = response["challenge-response"],
  }, token, deadline)
  if not verified then return nil, verify_err end
  tokens[ip] = token
  return token
end

function M.call(ip, path, method, payload)
  local deadline = socket.gettime() + CALL_BUDGET
  local token = tokens[ip]
  if not token then
    local err
    token, err = login(ip, deadline)
    if not token then return nil, err end
  end
  local result, err, code = request(ip, path, method or "GET", payload, token, deadline)
  if not result and (code == 401 or (err and err:find("Invalid Token", 1, true))) then
    tokens[ip] = nil
    token, err = login(ip, deadline)
    if not token then return nil, err end
    result, err = request(ip, path, method or "GET", payload, token, deadline)
  end
  return result, err
end

function M.gestalt(ip)
  return request(ip, "/xled/v1/gestalt", "GET")
end

function M.firmware_version(ip)
  local response, err = request(ip, "/xled/v1/fw/version", "GET")
  if not response then return nil, err end
  return response.version
end

function M.clear(ip)
  tokens[ip] = nil
end

return M
