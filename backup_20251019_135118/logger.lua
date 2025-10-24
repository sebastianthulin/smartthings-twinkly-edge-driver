-- Logger Service Implementation
-- Implements ILogger interface with fallback for SmartThings environment

local class = require "vendor.30log"
local interfaces = require "interfaces"

local Logger = interfaces.ILogger:extend("Logger")

function Logger:init()
  -- Try to use SmartThings log module, fall back to print
  local ok, st_log = pcall(require, "log")
  if ok then
    self._log = st_log
  else
    -- Fallback logger for local testing
    self._log = {
      debug = function(...) print("[DEBUG]", ...) end,
      info  = function(...) print("[INFO]", ...) end,
      warn  = function(...) print("[WARN]", ...) end,
      error = function(...) print("[ERROR]", ...) end,
    }
  end
end

function Logger:debug(...)
  self._log.debug(...)
end

function Logger:info(...)
  self._log.info(...)
end

function Logger:warn(...)
  self._log.warn(...)
end

function Logger:error(...)
  self._log.error(...)
end

return Logger