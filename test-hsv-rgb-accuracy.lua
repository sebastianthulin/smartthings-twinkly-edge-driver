-- Color Conversion Accuracy Test
-- Sets color using HSV, reads back RGB, and checks conversion accuracy

local ColorConverter = require "src/services/color_converter"
local config = require "src/twinkly/config"

local converter = ColorConverter:new()

local function test_hsv_to_rgb_accuracy(hue, sat, val)
  -- Normalize input to 0-1 for sat/val
  local h = hue
  local s = sat / config.color.max_percentage
  local v = val / config.color.max_percentage
  local r, g, b = converter:hsv_to_rgb(h, s, v)
  print(string.format("HSV(%d, %d, %d) -> RGB(%d, %d, %d)", hue, sat, val, r, g, b))
  -- Convert back to HSV
  local h2, s2, v2 = converter:rgb_to_hsv(r, g, b)
  print(string.format("RGB(%d, %d, %d) -> HSV(%.1f, %.2f, %.2f)", r, g, b, h2, s2, v2))
  -- Check if round-trip is close
  local hue_match = math.abs(h2 - h) < 5
  local sat_match = math.abs(s2 - s) < 0.05
  local val_match = math.abs(v2 - v) < 0.05
  print("Match:", hue_match, sat_match, val_match)
  return hue_match and sat_match and val_match
end

-- Test a few key colors
local test_cases = {
  {hue=0, sat=100, val=100},    -- Red
  {hue=120, sat=100, val=100}, -- Green
  {hue=240, sat=100, val=100}, -- Blue
  {hue=60, sat=100, val=100},  -- Yellow
  {hue=180, sat=100, val=100}, -- Cyan
  {hue=300, sat=100, val=100}, -- Magenta
  {hue=0, sat=0, val=100},     -- White
  {hue=0, sat=100, val=50},    -- Dark Red
}

local all_passed = true
for _, tc in ipairs(test_cases) do
  local passed = test_hsv_to_rgb_accuracy(tc.hue, tc.sat, tc.val)
  if not passed then all_passed = false end
end

if all_passed then
  print("\nAll HSV->RGB->HSV conversions are accurate!")
else
  print("\nSome conversions are inaccurate. Check color conversion logic.")
end
