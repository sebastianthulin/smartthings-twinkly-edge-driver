local http = require "socket.http"
local ltn12 = require "ltn12"
local json = require "dkjson"
local openssl_hmac = require "openssl.hmac"

local twinkly = {}
local sessions = {}

local function hmac_sha1(key, data)
  local h = openssl_hmac.new(key, "sha1")
  h:update(data)
  return (h:final(true))
end

local function login(ip)
  if not ip then return nil, "No IP provided" end

  -- Generate a random 16-byte base64 challenge
  local challenge = ""
  for i=1,16 do
    challenge = challenge .. string.char(math.random(0,255))
  end
  local b='ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/'
  local function base64enc(data)
    return ((data:gsub('.', function(x) 
      local r,bits='',x:byte()
      for i=8,1,-1 do r=r..(bits%2^i-bits%2^(i-1)>0 and '1' or '0') end
      return r;
    end)..'0000'):gsub('%d%d%d?%d?%d?%d?', function(x)
      if (#x < 6) then return '' end
      local c=0
      for i=1,6 do c=c+(x:sub(i,i)=='1' and 2^(6-i) or 0) end
      return b:sub(c+1,c+1)
    end)..({ '', '==', '=' })[#data%3+1])
  end
  local challenge_b64 = base64enc(challenge)

  local login_body = json.encode({ challenge = challenge_b64 })
  local resp = {}
  local res, code, headers, status = http.request{
    url = "http://" .. ip .. "/xled/v1/login",
    method = "POST",
    headers = {
      ["Content-Type"] = "application/json",
      ["Content-Length"] = tostring(#login_body)
    },
    source = ltn12.source.string(login_body),
    sink = ltn12.sink.table(resp),
  }
  if not res or code ~= 200 then
    return nil, "Login failed: " .. tostring(status)
  end
  local body = table.concat(resp)
  print("[login] Raw body: " .. body)
  local decoded = json.decode(body)
  if not decoded or not decoded.authentication_token or not decoded["challenge-response"] then
    return nil, "Login response missing fields. Body: " .. body
  end

  local token = decoded.authentication_token
  local challenge_resp = decoded["challenge-response"]

  -- Verify step
  local verify_body = json.encode({ ["challenge-response"] = challenge_resp })
  local vresp = {}
  local vres, vcode, vheaders, vstatus = http.request{
    url = "http://" .. ip .. "/xled/v1/verify",
    method = "POST",
    headers = {
      ["Content-Type"] = "application/json",
      ["Content-Length"] = tostring(#verify_body),
      ["X-Auth-Token"] = token
    },
    source = ltn12.source.string(verify_body),
    sink = ltn12.sink.table(vresp),
  }
  local vbody = table.concat(vresp)
  print("[verify] Raw body: " .. vbody)
  if not vres or vcode ~= 200 then
    return nil, "Verify failed: " .. tostring(vstatus) .. " Body: " .. vbody
  end

  sessions[ip] = token
  return token
end

local function ensure_token(ip)
  if sessions[ip] then
    return sessions[ip]
  end
  return login(ip)
end

function twinkly.set_mode(ip, mode)
  local token, err = ensure_token(ip)
  if not token then return nil, "No token: " .. tostring(err) end
  local body = json.encode({ mode = mode })
  local resp = {}
  local res, code, headers, status = http.request{
    url = "http://" .. ip .. "/xled/v1/led/mode",
    method = "POST",
    headers = {
      ["Content-Type"] = "application/json",
      ["Content-Length"] = tostring(#body),
      ["X-Auth-Token"] = token
    },
    source = ltn12.source.string(body),
    sink = ltn12.sink.table(resp),
  }
  local resp_body = table.concat(resp)
  -- Log raw response body
  -- print("set_mode response body:", resp_body)
  if not res or code ~= 200 then
    return nil, "Failed to set mode: " .. tostring(status) .. " Body: " .. resp_body
  end
  return true, resp_body
end

function twinkly.get_mode(ip)
  print("[get_mode] Entering with IP: " .. tostring(ip))
  local token, err = ensure_token(ip)
  print("[get_mode] Token: " .. tostring(token) .. " Err: " .. tostring(err))
  if not token then
    print("[get_mode] Exiting early: no token")
    return nil, "No token: " .. tostring(err)
  end

  local function fetch(path)
    print("[get_mode] Fetching path: " .. path)
    local resp = {}
    local res, code, _, status = http.request{
      url = "http://" .. ip .. path,
      method = "GET",
      headers = { ["X-Auth-Token"] = token },
      sink = ltn12.sink.table(resp),
    }
    local body = table.concat(resp)
    print("[get_mode] HTTP result: res=" .. tostring(res) .. " code=" .. tostring(code) .. " status=" .. tostring(status) .. " body=" .. body)
    return code, body
  end

  local code, body = fetch("/xled/v1/led/mode")
  if code ~= 200 or not body or body == "" then
    print("[get_mode] /status failed, trying /led/mode")
    code, body = fetch("/xled/v1/led/mode")
  end

  if code == 200 then
    local decoded, _, jerr = json.decode(body)
    if not decoded then
      print("[get_mode] JSON decode failed: " .. tostring(jerr))
      return nil, "Invalid JSON: " .. tostring(jerr) .. " Body: " .. body
    end
    local mode = decoded.mode
    if mode == "off" then
      print("[get_mode] Normalized mode: off")
      return "off", body
    else
      print("[get_mode] Normalized mode: on (raw was " .. tostring(mode) .. ")")
      return "on", body
    end
  else
    print("[get_mode] HTTP error: code=" .. tostring(code) .. " body=" .. tostring(body))
    return nil, "HTTP " .. tostring(code) .. " Body: " .. tostring(body)
  end
end



return twinkly
