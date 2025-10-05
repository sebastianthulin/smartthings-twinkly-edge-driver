local M = {}

-- Detect if we're running on SmartThings Edge Hub
-- The hub injects `cosock` globally — that’s the safest detection.
local function is_running_on_hub()
  -- Local override (for tests)
  if _G.IS_LOCAL_TEST then
    return false
  end

  -- If cosock is preloaded globally, we're on the hub
  local ok, _ = pcall(require, "cosock")
  return ok
end

if is_running_on_hub() then
  -- On hub: use cosock async HTTP
  local cosock = require "cosock"
  M.http = cosock.asyncify("socket.http")
else
  -- Local dev: blocking LuaSocket
  M.http = require "socket.http"
end

return M