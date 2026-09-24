local responses = {}
local requests = {}
local now = 0
package.loaded["twinkly.api"] = nil
package.preload["cosock"] = function()
  return {
    socket = {
      gettime = function() return now end,
      tcp = function()
        return {
          settimeout = function(_, n) assert(n > 0 and n <= 3); return 1 end,
          connect = function() return 1 end,
          receive = function() return "ok" end,
        }
      end,
    },
    asyncify = function()
      return { request = function(params)
        if params.source then params.request_body = params.source() end
        requests[#requests + 1] = params
        local reply = table.remove(responses, 1)
        assert(reply, "unexpected request")
        local conn = params.create()
        local connected, connect_err = conn:connect("device", 80)
        if not connected then return nil, connect_err end
        now = now + (reply.advance or 0)
        local received, receive_err = conn:receive()
        if not received then return nil, receive_err end
        params.sink(reply.body)
        return reply.ok, reply.code
      end }
    end,
  }
end
local api = require "twinkly.api"
local function queue(code, body, ok, advance)
  responses[#responses + 1] = { code = code, body = body,
    ok = ok == nil and 1 or ok, advance = advance }
end
queue(200, '{"code":1000,"authentication_token":"a","challenge-response":"b"}')
queue(200, '{"code":1000}')
queue(200, '{"code":1000,"mode":"movie"}')
assert(api.call("192.168.1.1", "/xled/v1/led/mode").mode == "movie")
assert(#requests == 3)
local challenge = require("dkjson").decode(requests[1].request_body).challenge
assert(#challenge == 44 and challenge:match("^[A-Za-z0-9+/]+=*$"), "login needs 32 base64 bytes")
assert(requests[2].headers["X-Auth-Token"] == "a")
queue(200, '{"code":1000,"mode":"off"}')
assert(api.call("192.168.1.1", "/xled/v1/led/mode").mode == "off")
assert(#requests == 4, "token must be reused")
queue(401, '{"code":1001}')
queue(200, '{"code":1000,"authentication_token":"c","challenge-response":"d"}')
queue(200, '{"code":1000}')
queue(200, '{"code":1000,"mode":"demo"}')
assert(api.call("192.168.1.1", "/xled/v1/led/mode").mode == "demo")
queue(200, '{"code":1104}')
assert(api.call("192.168.1.1", "/xled/v1/led/mode") == nil, "JSON error must fail")
queue(200, '{"code":1000}')
assert(api.gestalt("192.168.1.2").code == 1000)
queue(200, '{"code":1000,"version":"2.7.1"}')
assert(api.firmware_version("192.168.1.2") == "2.7.1")
queue(200, '{"code":1000}')
assert(api.call("192.168.1.1", "/xled/v1/led/out/brightness", "POST",
  { mode = "enabled", type = "A", value = 37 }))
local brightness_request = requests[#requests]
local brightness_body = require("dkjson").decode(brightness_request.request_body)
assert(brightness_request.method == "POST" and
  brightness_request.url:match("/xled/v1/led/out/brightness$") and
  brightness_request.headers["Content-Type"] == "application/json" and
  brightness_body.mode == "enabled" and brightness_body.type == "A" and
  brightness_body.value == 37, "brightness must be sent as an absolute percent")
queue(200, '{"code":1101}')
assert(api.call("192.168.1.1", "/xled/v1/led/out/brightness", "POST",
  { mode = "enabled", type = "A", value = 37 }) == nil,
  "Twinkly application error must not be treated as a successful dim")
queue("timeout", "", false)
assert(api.gestalt("192.168.1.3") == nil)
queue(200, '{"code":1000,"padding":"' .. string.rep("a", 262144) .. '"}')
local oversized, oversized_err = api.gestalt("192.168.1.3")
assert(oversized == nil and oversized_err == "Response too large",
  "an oversized response must stop before JSON decoding")
queue(200, '{"code":1000,"authentication_token":"e","challenge-response":"f"}', nil, 3)
queue(200, '{"code":1000}', nil, 3)
queue(200, '{"code":1000,"mode":"color"}', nil, 3)
local over_budget, budget_err = api.call("192.168.1.9", "/xled/v1/led/mode")
assert(over_budget == nil and budget_err == "Request deadline exceeded",
  "login, verification and command must share one total time budget")
local requests_before_expired_token = #requests
queue(401, '{"code":1001}', nil, 2)
queue(200, '{"code":1000,"authentication_token":"g","challenge-response":"h"}', nil, 3)
queue(200, '{"code":1000}', nil, 3)
over_budget, budget_err = api.call("192.168.1.1", "/xled/v1/led/mode")
assert(over_budget == nil and budget_err == "Request deadline exceeded" and
  #requests == requests_before_expired_token + 3,
  "401 reauthentication must not issue a command after the shared deadline")
assert(#responses == 0)
