-- Lookup Table Value Curve Test
-- Build a lookup table for HSV value curve to optimize round-trip accuracy

local ColorConverter = require "src/services/color_converter"
local config = require "src/twinkly/config"

-- Build lookup table for value mapping (0..1 in steps of 0.01)
local LUT_SIZE = 100
local lut = {}
for i = 0, LUT_SIZE do
  local v = i / LUT_SIZE
  -- You can use any curve here, e.g. log, exp, or a custom fit
  lut[i] = math.log(1 + (config.color.value_log_base - 1) * v) / math.log(config.color.value_log_base)
end

-- Inverse lookup: find closest input value for a given output value
local function inverse_lut(target)
  local best_i, best_err = 0, math.huge
  for i = 0, LUT_SIZE do
    local err = math.abs(lut[i] - target)
    if err < best_err then
      best_err = err
      best_i = i
    end
  end
  return best_i / LUT_SIZE
end

-- Test round-trip accuracy
local function test_lookup_accuracy(hue, sat, val)
  local h = hue
  local s = sat / config.color.max_percentage
  local v = val / config.color.max_percentage
  local mapped_v = lut[math.floor(v * LUT_SIZE + 0.5)]
  local converter = ColorConverter:new()
  local r, g, b = converter:hsv_to_rgb(h, s, mapped_v)
  print(string.format("HSV(%d, %d, %d) -> RGB(%d, %d, %d)", hue, sat, val, r, g, b))
  local h2, s2, v2 = converter:rgb_to_hsv(r, g, b)
  local inv_v = inverse_lut(v2)
  print(string.format("RGB(%d, %d, %d) -> HSV(%.1f, %.2f, %.2f) -> LUT-inverse: %.2f", r, g, b, h2, s2, v2, inv_v))
  print("Value match:", math.abs(inv_v - v) < 0.05)
  return inv_v
end

test_lookup_accuracy(0, 100, 50)
