-- Static Effects Feature Implementation
-- Handles predefined static effects (not retrievable from device)

local class = require "vendor.30log"

local StaticEffects = class("StaticEffects")

function StaticEffects:init()
  self._effects = self:_load_static_effects()
end

-- Load static predefined effects
function StaticEffects:_load_static_effects()
  return {
    {id = 1, name = "Rainbow Slow", description = "Slow rainbow color transition"},
    {id = 2, name = "Rainbow Fast", description = "Fast rainbow color transition"},
    {id = 3, name = "Rainbow Fade", description = "Fading rainbow effect"},
    {id = 4, name = "Rainbow Wave", description = "Wave-like rainbow effect"},
    {id = 5, name = "Rainbow Pulse", description = "Pulsing rainbow effect"},
    {id = 6, name = "Rainbow Spiral", description = "Spiral rainbow effect"},
    {id = 7, name = "Rainbow Chase", description = "Chasing rainbow effect"},
    {id = 8, name = "Rainbow Sparkle", description = "Sparkling rainbow effect"},
    {id = 9, name = "Rainbow Ripple", description = "Rippling rainbow effect"},
    {id = 10, name = "Rainbow Burst", description = "Bursting rainbow effect"},
    {id = 11, name = "Rainbow Flow", description = "Flowing rainbow effect"},
    {id = 12, name = "Rainbow Cascade", description = "Cascading rainbow effect"},
    {id = 13, name = "Sparkle White", description = "White sparkle effect"},
    {id = 14, name = "Sparkle Multicolor", description = "Multicolor sparkle effect"},
    {id = 15, name = "Sparkle Gold", description = "Gold sparkle effect"},
    {id = 16, name = "Sparkle Blue", description = "Blue sparkle effect"},
    {id = 17, name = "Sparkle Red", description = "Red sparkle effect"},
    {id = 18, name = "Sparkle Green", description = "Green sparkle effect"},
    {id = 19, name = "Sparkle Purple", description = "Purple sparkle effect"},
    {id = 20, name = "Sparkle Silver", description = "Silver sparkle effect"},
    {id = 21, name = "Sparkle Warm", description = "Warm sparkle effect"},
    {id = 22, name = "Sparkle Cool", description = "Cool sparkle effect"},
    {id = 23, name = "Twinkle Soft", description = "Soft twinkling effect"},
    {id = 24, name = "Twinkle Bright", description = "Bright twinkling effect"},
    {id = 25, name = "Twinkle Random", description = "Random twinkling effect"},
    {id = 26, name = "Twinkle Steady", description = "Steady twinkling effect"},
    {id = 27, name = "Twinkle Fast", description = "Fast twinkling effect"},
    {id = 28, name = "Twinkle Slow", description = "Slow twinkling effect"},
    {id = 29, name = "Twinkle Burst", description = "Bursting twinkling effect"},
    {id = 30, name = "Twinkle Wave", description = "Wave-like twinkling effect"},
    {id = 31, name = "Wave Red", description = "Red wave effect"},
    {id = 32, name = "Wave Blue", description = "Blue wave effect"},
    {id = 33, name = "Wave Green", description = "Green wave effect"},
    {id = 34, name = "Wave Multicolor", description = "Multicolor wave effect"},
    {id = 35, name = "Wave Ocean", description = "Ocean wave effect"},
    {id = 36, name = "Wave Sunset", description = "Sunset wave effect"},
    {id = 37, name = "Wave Aurora", description = "Aurora wave effect"},
    {id = 38, name = "Wave Pulse", description = "Pulsing wave effect"},
    {id = 39, name = "Solid Red", description = "Solid red color"},
    {id = 40, name = "Solid Green", description = "Solid green color"},
    {id = 41, name = "Solid Blue", description = "Solid blue color"},
    {id = 42, name = "Solid White", description = "Solid white color"},
    {id = 43, name = "Solid Yellow", description = "Solid yellow color"},
    {id = 44, name = "Solid Purple", description = "Solid purple color"},
    {id = 45, name = "Solid Orange", description = "Solid orange color"},
    {id = 46, name = "Solid Pink", description = "Solid pink color"},
    {id = 47, name = "Solid Cyan", description = "Solid cyan color"},
    {id = 48, name = "Solid Warm White", description = "Solid warm white color"},
    {id = 49, name = "Christmas Classic", description = "Classic Christmas colors"},
    {id = 50, name = "Christmas Green", description = "Christmas green theme"},
    {id = 51, name = "Halloween Orange", description = "Halloween orange theme"},
    {id = 52, name = "Halloween Spooky", description = "Spooky Halloween theme"},
    {id = 53, name = "Valentine Romantic", description = "Romantic Valentine theme"},
    {id = 54, name = "Patriotic USA", description = "Patriotic USA theme"},
    {id = 55, name = "Easter Pastel", description = "Easter pastel theme"},
    {id = 56, name = "Thanksgiving Autumn", description = "Thanksgiving autumn theme"},
    {id = 57, name = "New Year Gold", description = "New Year gold theme"},
    {id = 58, name = "St Patrick Green", description = "St Patrick green theme"},
    {id = 59, name = "Aurora Borealis", description = "Aurora borealis effect"},
    {id = 60, name = "Fire Flicker", description = "Fire flickering effect"},
    {id = 61, name = "Ocean Waves", description = "Ocean waves effect"},
    {id = 62, name = "Lightning Storm", description = "Lightning storm effect"},
    {id = 63, name = "Meteor Shower", description = "Meteor shower effect"},
    {id = 64, name = "Galaxy Swirl", description = "Galaxy swirling effect"},
    {id = 65, name = "Neon Glow", description = "Neon glowing effect"},
    {id = 66, name = "Plasma Flow", description = "Plasma flowing effect"},
    {id = 67, name = "Crystal Shine", description = "Crystal shining effect"},
    {id = 68, name = "Magic Sparkle", description = "Magic sparkling effect"},
    {id = 69, name = "Disco Ball", description = "Disco ball effect"},
    {id = 70, name = "Laser Show", description = "Laser show effect"},
    {id = 71, name = "Candle Flicker", description = "Candle flickering effect"},
    {id = 72, name = "Campfire Glow", description = "Campfire glowing effect"},
    {id = 73, name = "Moonlight Soft", description = "Soft moonlight effect"},
    {id = 74, name = "Sunrise Warm", description = "Warm sunrise effect"},
    {id = 75, name = "Sunset Cool", description = "Cool sunset effect"},
    {id = 76, name = "Starfield Deep", description = "Deep starfield effect"},
    {id = 77, name = "Comet Tail", description = "Comet tail effect"},
    {id = 78, name = "Energy Pulse", description = "Energy pulsing effect"}
  }
end

-- List all static effects
function StaticEffects:list_effects()
  return self._effects
end

-- Get effect by ID
function StaticEffects:get_effect_by_id(effect_id)
  for _, effect in ipairs(self._effects) do
    if effect.id == effect_id then
      return effect
    end
  end
  return nil
end

-- Check if effect ID is valid
function StaticEffects:is_valid_effect_id(effect_id)
  return self:get_effect_by_id(effect_id) ~= nil
end

return StaticEffects
