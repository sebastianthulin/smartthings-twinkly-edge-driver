package.loaded["twinkly.discovery"] = nil
local replies = {
  { "\32\87\168\192OKTwinkly_9C76A9\0", "192.168.1.2" },
  { "\1\2\3\4yuabc\0", "192.168.1.2" },
  { "garbage", "192.168.1.3" },
}
local time = 0
package.loaded["cosock"] = {
  socket = {
    gettime = function() time = time + 0.1; return time end,
    udp = function()
      return {
        settimeout = function() end, setoption = function() end,
        sendto = function(_, packet, address, port)
          assert(packet == "\1discover" and address == "255.255.255.255" and port == 5555)
          return 9
        end,
        receivefrom = function()
          local reply = table.remove(replies, 1)
          if reply then return reply[1], reply[2] end
          return nil, "timeout"
        end,
        close = function() end,
      }
    end,
  },
}
package.loaded["twinkly.api"] = {
  gestalt = function(ip)
    assert(ip == "192.168.1.2")
    return { code = 1000, product_name = "Twinkly", mac = "AA:BB:CC:DD:EE:FF", device_name = "Tree" }
  end,
  firmware_version = function() return "2.7.1" end,
}
local discovery = require "twinkly.discovery"
local devices, created = {}, 0
local driver = {
  get_devices = function() return devices end,
  try_create_device = function(_, meta)
    created = created + 1
    assert(meta.device_network_id == "twinkly-aabbccddeeff")
    assert(meta.profile == "twinkly-color-light")
    devices[1] = { device_network_id = meta.device_network_id, get_field = function() end,
      set_field = function(self, key, value) self[key] = value end }
  end,
}
assert(discovery.scan(driver))
assert(created == 1)
assert(discovery.pending_ip("twinkly-aabbccddeeff") == "192.168.1.2")
replies[1] = { "\1\2\3\4yuabc\0", "192.168.1.4" }
package.loaded["twinkly.api"].gestalt = function()
  return { code = 1000, product_name = "Twinkly", mac = "AA:BB:CC:DD:EE:FF" }
end
time = 0
assert(discovery.scan(driver))
assert(created == 1 and devices[1].ipAddress == "192.168.1.4")
assert(discovery.pending_ip("twinkly-aabbccddeeff") == "192.168.1.4")
time = 0
assert(discovery.scan(driver))
assert(created == 1, "empty scan must not create a placeholder")
local unknown_driver = { get_devices = function() return {} end,
  try_create_device = function() error("lookup-only scan created a device") end }
replies[1] = { "\1\2\3\4yuabc\0", "192.168.1.5" }
time = 0
assert(discovery.scan(unknown_driver, false))
local old_device = {
  device_network_id = "twinkly-001122334455",
  get_field = function(_, key) if key == "ipAddress" then return "192.168.1.5" end end,
  set_field = function() error("new device must not overwrite another MAC") end,
}
local collision_creates = 0
local collision_driver = {
  get_devices = function() return { old_device } end,
  try_create_device = function(_, meta)
    collision_creates = collision_creates + 1
    assert(meta.device_network_id == "twinkly-aabbccddeeff")
  end,
}
replies[1] = { "\1\2\3\4yuabc\0", "192.168.1.5" }
time = 0
assert(discovery.scan(collision_driver))
assert(collision_creates == 1, "reused IP must not merge different MACs")
local pending_creates = 0
local pending_driver = {
  get_devices = function() return {} end,
  try_create_device = function() pending_creates = pending_creates + 1 end,
}
replies[1] = { "\1\2\3\4yuabc\0", "192.168.1.6" }
replies[2] = { "\1\2\3\4yuabc\0", "192.168.1.7" }
time = 0
assert(discovery.scan(pending_driver))
assert(pending_creates == 1, "two replies for one MAC must not request two devices")
replies[1] = { "\1\2\3\4yuabc\0", "192.168.1.8" }
time = 1
assert(discovery.scan(pending_driver))
assert(pending_creates == 1, "a second scan must not create the same pending device again")
replies[1] = { "\1\2\3\4yuabc\0", "192.168.1.8" }
time = 40
assert(discovery.scan(pending_driver))
assert(pending_creates == 2, "a failed creation must be retryable after the cooldown")
local legacy = {
  device_network_id = "twinkly-1700000000",
  get_field = function(_, key) if key == "ipAddress" then return "192.168.1.5" end end,
  set_field = function(self, key, value) self[key] = value end,
}
collision_driver.get_devices = function() return { legacy } end
replies[1] = { "\1\2\3\4yuabc\0", "192.168.1.5" }
time = 0
assert(discovery.scan(collision_driver))
assert(collision_creates == 1 and legacy.ipAddress == "192.168.1.5",
  "legacy placeholder should retain IP migration behavior")
assert(discovery.network_id({ product_name = "Other", mac = "AA:BB:CC:DD:EE:FF" }) == nil)
assert(discovery.profile_for({ fw_family = "D" }, "2.3.4") == "twinkly-switch")
assert(discovery.profile_for({ fw_family = "D" }, "2.3.5") == "twinkly-dimmer")
assert(discovery.profile_for({ fw_family = "F" }, "2.4.2") == "twinkly-dimmer")
assert(discovery.profile_for({ fw_family = "G" }, "2.4.20") == "twinkly-switch")
assert(discovery.profile_for({ fw_family = "G" }, "2.7.1") == "twinkly-color-light")
assert(discovery.profile_for({}, "unknown") == "twinkly-switch")
