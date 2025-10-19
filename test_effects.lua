#!/usr/bin/env lua

-- Simple test script to verify predefined effects
package.path = package.path .. ";src/?.lua"

local twinkly = require "twinkly"

print("Testing predefined effects...")

-- Test listing effects (should not require device IP)
local effects = twinkly.list_effects()

if effects then
    print("✓ Successfully got effects list with", #effects, "effects")
    
    -- Show first few effects
    for i = 1, math.min(5, #effects) do
        local effect = effects[i]
        print("  " .. i .. ". " .. (effect.name or "Unknown") .. " (ID: " .. (effect.id or "Unknown") .. ")")
    end
    
    if #effects > 5 then
        print("  ... and", #effects - 5, "more effects")
    end
else
    print("✗ Failed to get effects list")
end

print("Test completed.")