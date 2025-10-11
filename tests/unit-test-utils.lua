-- Unit tests for utilities module
package.path = package.path .. ";../src/?.lua;./?.lua"
_G.IS_LOCAL_TEST = true

local test_utils = require("test-utils")
local utils = require("twinkly.utils")

local test = test_utils.test_framework

-- Test utils.random_base64
test.describe("utils.random_base64 generates base64 string", function()
  local result = utils.random_base64(10)
  test.assert_not_nil(result, "Should generate a string")
  test.assert_true(type(result) == "string", "Result should be a string")
  test.assert_true(#result > 0, "Generated string should not be empty")
end)

test.describe("utils.random_base64 generates different strings", function()
  local result1 = utils.random_base64(10)
  local result2 = utils.random_base64(10)
  test.assert_true(result1 ~= result2, "Should generate different strings each time")
end)

-- Run tests
if not test.run_all() then
  os.exit(1)
end