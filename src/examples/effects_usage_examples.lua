-- Effects Usage Examples
-- This file demonstrates how to use the new effects functionality

local twinkly = require("twinkly")

-- Example 1: List all available effects (both builtin and user-downloaded)
local function list_all_effects(ip)
  print("Listing all effects for device " .. ip)
  
  local effects = twinkly.list_effects(ip, "all")
  if effects then
    print("Found " .. #effects .. " effects:")
    for i, effect in ipairs(effects) do
      print(string.format("  %d. %s (ID: %s, Type: %s)", 
        i, effect.name or "unnamed", effect.id or "unknown", effect.type or "unknown"))
    end
  else
    print("Failed to list effects")
  end
  
  return effects
end

-- Example 2: List only builtin effects
local function list_builtin_effects(ip)
  print("Listing builtin effects for device " .. ip)
  
  local effects = twinkly.list_effects(ip, "builtin")
  if effects then
    print("Found " .. #effects .. " builtin effects:")
    for i, effect in ipairs(effects) do
      print(string.format("  %d. %s (ID: %s)", 
        i, effect.name or "unnamed", effect.id or "unknown"))
    end
  else
    print("Failed to list builtin effects")
  end
  
  return effects
end

-- Example 3: List only user-downloaded effects
local function list_user_effects(ip)
  print("Listing user effects for device " .. ip)
  
  local effects = twinkly.list_effects(ip, "user")
  if effects then
    print("Found " .. #effects .. " user effects:")
    for i, effect in ipairs(effects) do
      print(string.format("  %d. %s (ID: %s)", 
        i, effect.name or "unnamed", effect.id or "unknown"))
    end
  else
    print("Failed to list user effects")
  end
  
  return effects
end

-- Example 4: Activate an effect by ID
local function activate_effect(ip, effect_id, effect_type)
  print("Activating " .. tostring(effect_type or "builtin") .. " effect " .. tostring(effect_id) .. " on device " .. ip)
  
  local success, message = twinkly.set_effect(ip, effect_id, effect_type)
  if success then
    print("Effect activated successfully!")
    print("Response: " .. tostring(message))
  else
    print("Failed to activate effect: " .. tostring(message))
  end
  
  return success
end

-- Example 5: Complete workflow - list effects and activate the first one
local function demo_workflow(ip)
  print("=== Effects Demo Workflow ===")
  print("Device IP: " .. ip)
  print()
  
  -- Step 1: List all effects
  local effects = list_all_effects(ip)
  if not effects or #effects == 0 then
    print("No effects found. Cannot continue demo.")
    return false
  end
  
  print()
  
  -- Step 2: Show favorite effects (first few are often favorites/defaults)
  print("Favorite effects (first 3):")
  for i = 1, math.min(3, #effects) do
    local effect = effects[i]
    print(string.format("  ⭐ %s (ID: %s, Type: %s)", 
      effect.name or "unnamed", effect.id or "unknown", effect.type or "unknown"))
  end
  
  print()
  
  -- Step 3: Activate the first effect as a demo
  local first_effect = effects[1]
  if first_effect and first_effect.id then
    print("Activating first effect as demo...")
    activate_effect(ip, first_effect.id)
  else
    print("Cannot activate effect - missing ID")
    return false
  end
  
  return true
end

-- Export functions for use
return {
  list_all_effects = list_all_effects,
  list_builtin_effects = list_builtin_effects,
  list_user_effects = list_user_effects,
  activate_effect = activate_effect,
  demo_workflow = demo_workflow
}