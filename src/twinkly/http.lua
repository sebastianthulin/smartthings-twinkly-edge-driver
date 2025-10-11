local M = {}

-- Force plain LuaSocket when running locally
-- On the hub, SmartThings injects cosock and you can switch back.
-- Detect if we're running in local test environment
local function is_running_on_hub()
  -- Check for local test environment variable
  if _G.IS_LOCAL_TEST then
    return false
  end
  -- Check if we have SmartThings environment
  local ok, _ = pcall(require, "st.driver")
  return ok
end

if is_running_on_hub() then
  -- On hub, cosock is safe
  local cosock = require "cosock"
  M.http = cosock.asyncify("socket.http")
else
  -- Local dev: just use blocking LuaSocket
  M.http = require "socket.http"
end

return M