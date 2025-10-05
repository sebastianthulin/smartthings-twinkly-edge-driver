local M = {}

-- You can define this in your test script:
-- _G.IS_LOCAL_TEST = true

local function is_running_on_hub()
  if _G.IS_LOCAL_TEST then
    return false
  end

  -- On hub, cosock is preloaded globally
  local ok, cosock = pcall(require, "cosock")
  return ok and type(cosock.asyncify) == "function"
end

if is_running_on_hub() then
  local cosock = require "cosock"
  M.http = cosock.asyncify("socket.http")
  print("[twinkly.http] Using cosock.asyncify(socket.http)")
else
  M.http = require "socket.http"
  print("[twinkly.http] Using blocking socket.http (local mode)")
end

return M