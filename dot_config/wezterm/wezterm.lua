local wezterm = require 'wezterm';
-- local mux = wezterm.mux
local keymap = require 'keymap'
local appearance = require 'appearance'
local actions = require 'actions'
local config = {}
if wezterm.config_builder then
  config = wezterm.config_builder()
end

--
-- key
--
keymap.apply(config)

--
-- appearance
--
appearance.apply(config)

--
-- actions (launch_menu, default_prog)
--
actions.apply(config)

--
-- other configration
--
config.use_ime = true

return config
