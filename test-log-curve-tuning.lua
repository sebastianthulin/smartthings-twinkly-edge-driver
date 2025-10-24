-- Logarithmic Value Curve Test
-- Test different log bases for value curve to optimize HSV->RGB->HSV round-trip accuracy

local ColorConverter = require "src/services/color_converter"
local config = require "src/twinkly/config"

local function test_log_base(base)
  config.color.value_log_base = base
  local converter = ColorConverter:new()
  print("\nTesting log base:", base)
  local hue, sat, val = 0, 100, 50 -- Dark red
  local h = hue
  local s = sat / config.color.max_percentage
  local v = val / config.color.max_percentage
  local r, g, b = converter:hsv_to_rgb(h, s, v)
  print(string.format("HSV(%d, %d, %d) -> RGB(%d, %d, %d)", hue, sat, val, r, g, b))
  local h2, s2, v2 = converter:rgb_to_hsv(r, g, b)
  print(string.format("RGB(%d, %d, %d) -> HSV(%.1f, %.2f, %.2f)", r, g, b, h2, s2, v2))
  print("Value match:", math.abs(v2 - v) < 0.05)
  return v2
end

local best_base, best_error = nil, math.huge
for base = 2, 20 do
  local v2 = test_log_base(base)
  local v = 0.5
  local error = math.abs(v2 - v)
  if error < best_error then
    best_error = error
    best_base = base
  end
end

print("\nBest log base for value curve:", best_base, "(error:", best_error, ")")
