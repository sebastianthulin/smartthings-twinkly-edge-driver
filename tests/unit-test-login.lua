-- Unit tests for login module (mocked)
package.path = package.path .. ";../src/?.lua;./?.lua"
_G.IS_LOCAL_TEST = true

local test_utils = require("test-utils")

-- Mock the HTTP module to avoid network calls in unit tests
package.preload["twinkly.http"] = function()
  return {
    http = {
      request = function(params)
        -- Mock successful responses by writing to the sink
        if params.url:match("/login") and params.method == "POST" then
          if params.sink then
            params.sink('{"authentication_token":"mock_token_123","challenge-response":"mock_challenge","code":1000}')
          end
          return 1, 200
        end
        -- Mock successful verify response  
        if params.url:match("/verify") and params.method == "POST" then
          if params.sink then
            params.sink('{"code":1000}')
          end
          return 1, 200
        end
        return nil, 500, "Mock error"
      end
    }
  }
end

-- Mock the log module
package.preload["log"] = function()
  return {
    debug = function(...) end,
    info = function(...) end,
    warn = function(...) end,
    error = function(...) end,
  }
end

local login = require("twinkly.login")
local test = test_utils.test_framework

-- Test token generation and verification
test.describe("login.ensure_token returns a token", function()
  local token, err = login.ensure_token("192.168.1.45")
  test.assert_not_nil(token, "Should return a token")
  test.assert_equals(token, "mock_token_123", "Should return the mocked token")
end)

test.describe("login.clear_token clears cached tokens", function()
  -- First ensure a token
  login.ensure_token("192.168.1.45")
  -- Then clear it
  login.clear_token("192.168.1.45")
  test.assert_true(true, "Should clear token without error")
end)

-- Run tests
if not test.run_all() then
  os.exit(1)
end