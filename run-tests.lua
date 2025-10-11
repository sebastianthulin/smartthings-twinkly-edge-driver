#!/usr/bin/env lua5.3
-- Test runner for Twinkly Edge Driver
-- Usage: lua5.3 run-tests.lua [test-type]
-- test-type can be: all, unit, integration

package.path = package.path .. ";tests/?.lua;src/?.lua"

local test_type = arg and arg[1] or "all"

print("Twinkly Edge Driver Test Suite")
print("==============================")
print("Test type: " .. test_type)
print("")

-- Function to run a test file
local function run_test_file(filepath, test_name)
  print("Running " .. test_name .. "...")
  local cmd = "cd tests && lua5.3 " .. filepath
  local result = os.execute(cmd)
  
  -- On different systems, os.execute returns different values
  local success = (result == true or result == 0)
  
  if success then
    print("✓ " .. test_name .. " PASSED")
    return true
  else
    print("✗ " .. test_name .. " FAILED (exit code: " .. tostring(result) .. ")")
    return false
  end
end

local function run_unit_tests()
  print("=== Running Unit Tests ===")
  local all_passed = true
  
  local unit_tests = {
    {"unit-test-utils.lua", "Utils Tests"},
    {"unit-test-config.lua", "Config Tests"},
    {"unit-test-login.lua", "Login Tests"}, 
    {"unit-test-driver.lua", "Driver Tests"}
  }
  
  for _, test_info in ipairs(unit_tests) do
    if not run_test_file(test_info[1], test_info[2]) then
      all_passed = false
    end
  end
  
  return all_passed
end

local function run_integration_tests()
  print("\n=== Running Integration Tests ===")
  print("Note: Integration tests require a real Twinkly device or IP configuration")
  
  local all_passed = true
  
  local integration_tests = {
    {"integration-test-device.lua", "Device Integration Tests"}
  }
  
  for _, test_info in ipairs(integration_tests) do
    if not run_test_file(test_info[1], test_info[2]) then
      all_passed = false
    end
  end
  
  return all_passed
end

-- Main test execution
local unit_passed = false
local integration_passed = false

if test_type == "all" or test_type == "unit" then
  unit_passed = run_unit_tests()
end

if test_type == "all" or test_type == "integration" then
  integration_passed = run_integration_tests()
end

-- Print summary
print("\n=== Test Summary ===")

if test_type == "unit" then
  if unit_passed then
    print("✓ All unit tests passed!")
    os.exit(0)
  else
    print("✗ Some unit tests failed")
    os.exit(1)
  end
elseif test_type == "integration" then
  if integration_passed then
    print("✓ All integration tests passed!")
    os.exit(0)
  else
    print("✗ Some integration tests failed")
    os.exit(1)
  end
else -- test_type == "all"
  local overall_passed = unit_passed and integration_passed
  
  if unit_passed then
    print("✓ Unit tests: PASSED")
  else
    print("✗ Unit tests: FAILED")
  end
  
  if integration_passed then
    print("✓ Integration tests: PASSED")
  else
    print("✗ Integration tests: FAILED")
  end
  
  if overall_passed then
    print("\n🎉 All tests passed!")
    os.exit(0)
  else
    print("\n❌ Some tests failed")
    os.exit(1)
  end
end