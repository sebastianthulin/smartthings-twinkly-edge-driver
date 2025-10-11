-- Example test configuration file
-- Copy this to test-config.lua and modify as needed
-- NOTE: test-config.lua is ignored by git for security

local config = {
  -- IP address of your Twinkly device for testing
  -- This will be used if the IP environment variable is not set
  default_ip = "192.168.1.45",
  
  -- Test timeout in seconds
  timeout = 10,
  
  -- Retry settings
  retries = 3,
  retry_delay = 1,
  
  -- Test settings
  test_brightness_levels = {10, 50, 100},
  test_colors = {
    {red = 255, green = 0, blue = 0, name = "red"},
    {red = 0, green = 255, blue = 0, name = "green"},
    {red = 0, green = 0, blue = 255, name = "blue"},
    {red = 255, green = 255, blue = 255, name = "white"},
  },
  test_hsv_colors = {
    {hue = 0, sat = 100, val = 100, name = "red_hsv"},
    {hue = 120, sat = 100, val = 80, name = "green_hsv"},
    {hue = 240, sat = 100, val = 60, name = "blue_hsv"},
  },
  
  -- Mock SmartThings environment for unit tests
  mock_smartthings = true,
}

return config