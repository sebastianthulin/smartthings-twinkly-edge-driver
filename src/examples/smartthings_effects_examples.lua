-- SmartThings Effects Integration Examples
-- This file demonstrates how the new SmartThings GUI effects integration works

local twinkly = require("twinkly")

-- Example: How effects work in SmartThings
local function demonstrate_smartthings_effects_integration()
  print("=== SmartThings Effects Integration Demo ===")
  print("This demonstrates how effects work within SmartThings app")
  print()
  
  print("Features available in SmartThings GUI:")
  print("1. List Effects Command - Users can see all available effects")
  print("2. Set Effect Command - Users can activate specific effects")
  print("3. Current Effect Status - Shows which effect is currently active")
  print("4. Last Effect Memory - Restores last effect when turning device on")
  print()
  
  print("SmartThings Custom Capability: sebastianthulin44463.twinklyEffects")
  print("Commands:")
  print("  - listEffects() - Get all available effects")
  print("  - setEffect(effectId) - Activate a specific effect")
  print()
  print("Attributes:")
  print("  - availableEffects - List of all effects with id, name, type")
  print("  - currentEffect - Currently active effect with id and name")
  print()
end

-- Example: Programmatic usage of effects functions
local function demonstrate_programmatic_usage(ip)
  print("=== Programmatic Effects Usage ===")
  print("Device IP: " .. ip)
  print()
  
  -- 1. List all effects (same as SmartThings listEffects command)
  print("1. Listing all effects...")
  local effects = twinkly.list_effects(ip, "all")
  if effects then
    print("Found " .. #effects .. " effects:")
    for i, effect in ipairs(effects) do
      print(string.format("  %d. %s (ID: %s, Type: %s)", 
        i, effect.name or "unnamed", effect.id or "unknown", effect.type or "builtin"))
    end
  else
    print("Failed to list effects")
    return
  end
  print()
  
  -- 2. Activate an effect (same as SmartThings setEffect command)
  if #effects > 0 then
    local test_effect = effects[1]
    print("2. Activating effect: " .. tostring(test_effect.name) .. " (type: " .. tostring(test_effect.type) .. ")")
    local success = twinkly.set_effect(ip, test_effect.id, test_effect.type)
    if success then
      print("Effect activated successfully!")
      
      -- 3. Get current effect (used by SmartThings for status updates)
      local current = twinkly.get_effect(ip)
      if current then
        print("Current effect: " .. tostring(current.name) .. " (ID: " .. tostring(current.id) .. ")")
      else
        print("Note: Device firmware may not support getting current effect status")
      end
    else
      print("Failed to activate effect")
    end
  end
  print()
  
  -- 4. Demonstrate "remember last effect" feature
  print("3. Demonstrating 'remember last effect' feature...")
  print("When you turn on the device via SmartThings switch after setting an effect,")
  print("it will automatically restore the last used effect instead of default mode.")
  print()
end

-- Example: Integration workflow as seen from SmartThings app
local function demonstrate_smartthings_workflow()
  print("=== SmartThings App Workflow ===")
  print()
  print("User Experience in SmartThings App:")
  print("1. User opens Twinkly device in SmartThings app")
  print("2. User sees standard controls: On/Off, Brightness, Color")
  print("3. User also sees Effects section with:")
  print("   - 'List Effects' button to refresh available effects")  
  print("   - 'Set Effect' command with effect ID input")
  print("   - Current effect status display")
  print()
  print("Smart Features:")
  print("- When user activates an effect, device automatically turns on")
  print("- Effect ID is remembered for next time device is turned on")
  print("- Effects list includes both built-in and user-downloaded effects")
  print("- Status updates show current effect information")
  print()
  print("Integration with other controls:")
  print("- Turn Off: Works normally, stops any effect")
  print("- Turn On: Restores last effect if available, otherwise default mode")
  print("- Brightness: Works with effects (dims the effect)")
  print("- Color: May override effect with solid color (device-dependent)")
  print()
end

-- Export functions for demonstration
return {
  demonstrate_smartthings_effects_integration = demonstrate_smartthings_effects_integration,
  demonstrate_programmatic_usage = demonstrate_programmatic_usage,
  demonstrate_smartthings_workflow = demonstrate_smartthings_workflow
}