package.path = "./src/?.lua;./tests/?.lua;" .. package.path
for _, test in ipairs({ "test_api", "test_discovery", "test_scenes", "test_driver" }) do
  require(test)
  print(test .. " passed")
end
