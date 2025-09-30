local login_module = require "twinkly.login"
local control_module = require "twinkly.control"
local mode_module = require "twinkly.mode"

local twinkly = {}

-- Login / token handling
twinkly.login = login_module.login
twinkly.ensure_token = login_module.ensure_token

-- Control (on/off, effects, etc.)
twinkly.set_mode = control_module.set_mode

-- Status / mode query
twinkly.get_mode = mode_module.get_mode

return twinkly