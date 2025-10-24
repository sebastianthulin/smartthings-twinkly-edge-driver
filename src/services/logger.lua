-- Logger Service Implementation
-- Implements ILogger interface with fallback for SmartThings environment

local class = require "vendor.30log"
local interfaces = require "interfaces"

local Logger = interfaces.ILogger:extend("Logger")

function Logger:init()
  -- Try to use SmartThings log module, fall back to print and file
  local ok, st_log = pcall(require, "log")
  if ok then
    self._log = st_log
    self._write_to_file = function() end
  else
    -- Fallback logger for local testing
    local log_file_path = assert(os.getenv("PWD")) .. "/test-logs/latest.log"
    local log_dir = assert(os.getenv("PWD")) .. "/test-logs"
    local function write_to_file(level, ...)
      local msg = table.concat({level, os.date("%Y-%m-%d %H:%M:%S"), ...}, " ")
      -- Ensure log directory exists
      os.execute("mkdir -p '" .. log_dir .. "'")
      local ok, f = pcall(io.open, log_file_path, "a")
      if ok and f then
        f:write(msg .. "\n")
        f:close()
      else
        print("[LOGGER ERROR] Failed to write to log file:", log_file_path)
        if not ok then
          print("[LOGGER ERROR] io.open error:", f)
        end
      end
    end
    self._write_to_file = write_to_file
    self._log = {
      debug = function(...) print("[DEBUG]", ...); write_to_file("[DEBUG]", ...) end,
      info  = function(...) print("[INFO]", ...); write_to_file("[INFO]", ...) end,
      warn  = function(...) print("[WARN]", ...); write_to_file("[WARN]", ...) end,
      error = function(...) print("[ERROR]", ...); write_to_file("[ERROR]", ...) end,
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