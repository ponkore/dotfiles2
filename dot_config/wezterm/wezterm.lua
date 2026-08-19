local wezterm = require 'wezterm';
-- local mux = wezterm.mux
local keymap = require 'keymap'
local appearance = require 'appearance'
local actions = require 'actions'
local window = require 'window'
local workspace = require 'workspace'
local title = require 'title'
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
-- window size / position (起動時に作業領域いっぱいの高さ + 右端寄せ)
--
window.apply(config)

--
-- workspace (外部から SwitchToWorkspace するためのイベントハンドラ)
--
workspace.apply(config)

--
-- window title
--
title.apply(config)

--
-- other configration
--
config.use_ime = true

return config
