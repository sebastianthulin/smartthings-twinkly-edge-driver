local M = {}

-- Force plain LuaSocket when running locally
-- On the hub, SmartThings injects cosock and you can switch back.
local function is_running_on_hub()
  -- crude detection: SmartThings Edge sets ST edge paths and env
  return (os.getenv("EDGE_DRIVER_PACKAGE_ID") ~= nil)
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