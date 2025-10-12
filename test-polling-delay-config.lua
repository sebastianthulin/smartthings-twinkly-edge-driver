#!/usr/bin/env lua

-- Test to verify the new polling_resume_delay configuration works

print("Testing polling_resume_delay configuration...")

-- Load config module
local config = require("src.twinkly.config")

-- Test that the new polling_resume_delay setting exists
if config.timing.polling_resume_delay then
    print("✓ polling_resume_delay found in config: " .. config.timing.polling_resume_delay)
else
    print("✗ polling_resume_delay NOT found in config")
    os.exit(1)
end

-- Test that it's a reasonable value
local delay = config.timing.polling_resume_delay
if type(delay) == "number" and delay > 0 and delay <= 10 then
    print("✓ polling_resume_delay has reasonable value: " .. delay .. " seconds")
else
    print("✗ polling_resume_delay has invalid value: " .. tostring(delay))
    os.exit(1)
end

-- Test that other timing configs still work
if config.timing.default_poll_interval and config.timing.reauth_delay then
    print("✓ Other timing configurations still work")
else
    print("✗ Other timing configurations broken")
    os.exit(1)
end

print("🎉 All polling delay configuration tests passed!")