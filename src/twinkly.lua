local login_module = require "twinkly.login"
local control_module = require "twinkly.control"
local mode_module = require "twinkly.mode"

local twinkly = {}

-- Login / token handling
twinkly.login = login_module.login
twinkly.ensure_token = login_module.ensure_token

-- Control (on/off, effects, etc.)
twinkly.set_mode = control_module.set_mode

-- Brightness control
twinkly.set_brightness = control_module.set_brightness
twinkly.get_brightness = control_module.get_brightness

-- Color control
twinkly.set_color_rgb = control_module.set_color_rgb
twinkly.set_color_hsv = control_module.set_color_hsv
twinkly.get_color = control_module.get_color

-- Status / mode query
twinkly.get_mode = mode_module.get_mode

return twinkly