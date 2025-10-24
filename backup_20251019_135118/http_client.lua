-- HTTP Client Service Implementation
-- Implements IHttpClient interface with proper abstraction

local class = require "vendor.30log"
local interfaces = require "interfaces"
local ltn12 = require "ltn12"

local HttpClient = interfaces.IHttpClient:extend("HttpClient")

function HttpClient:init(logger)
  self._logger = logger or require("services.logger"):new()
  
  -- Initialize HTTP module (cosock on hub, socket.http for local)
  self._http_module = self:_initialize_http()
end

function HttpClient:_initialize_http()
  -- Force plain LuaSocket when running locally  
  -- On the hub, SmartThings injects cosock
  local function is_running_on_hub()
    return pcall(require, "st.driver")
  end

  if is_running_on_hub() then
    -- On hub, cosock is safe
    local cosock = require "cosock"
    return cosock.asyncify("socket.http")
  else
    -- Local dev: use blocking LuaSocket
    return require "socket.http"
  end
end

-- Main request method implementing the IHttpClient interface
function HttpClient:request(params)
  assert(params, "Request parameters are required")
  assert(params.url, "URL is required")
  
  local method = params.method or "GET"
  local headers = params.headers or {}
  local body = params.body
  local timeout = params.timeout or 30
  
  self._logger:debug(string.format("[HTTP %s] %s", method, params.url))
  
  -- Prepare sink for response
  local resp_table = {}
  local sink = ltn12.sink.table(resp_table)
  
  -- Prepare source if body is provided
  local source = nil
  if body then
    source = ltn12.source.string(body)
    headers["Content-Length"] = headers["Content-Length"] or tostring(#body)
  end
  
  -- Execute the HTTP request
  local result, status_code, response_headers, status_line = self._http_module.request({
    url = params.url,
    method = method,
    headers = headers,
    source = source,
    sink = sink,
    timeout = timeout
  })
  
  local response_body = table.concat(resp_table)
  
  self._logger:debug(string.format("[HTTP %s] Response: code=%s, body_length=%d", 
    method, tostring(status_code), #response_body))
  
  return {
    success = result ~= nil,
    status_code = status_code,
    body = response_body,
    headers = response_headers,
    status_line = status_line
  }
end

-- Convenience methods for common HTTP operations
function HttpClient:get(url, headers, timeout)
  return self:request({
    url = url,
    method = "GET", 
    headers = headers,
    timeout = timeout
  })
end

function HttpClient:post(url, body, headers, timeout)
  local req_headers = headers or {}
  if body and not req_headers["Content-Type"] then
    req_headers["Content-Type"] = "application/json"
  end
  
  return self:request({
    url = url,
    method = "POST",
    body = body,
    headers = req_headers,
    timeout = timeout
  })
end

function HttpClient:put(url, body, headers, timeout)
  local req_headers = headers or {}
  if body and not req_headers["Content-Type"] then
    req_headers["Content-Type"] = "application/json"
  end
  
  return self:request({
    url = url,
    method = "PUT", 
    body = body,
    headers = req_headers,
    timeout = timeout
  })
end

return HttpClient