local wezterm = require 'wezterm';
-- local mux = wezterm.mux
local keymap = require 'keymap'
local appearance = require 'appearance'
local actions = require 'actions'
local window = require 'window'
local workspace = require 'workspace'
local title = require 'title'
local dialog = require 'dialog'
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
-- message dialog (外部から SetUserVar でメッセージを表示するためのハンドラ)
--
dialog.apply(config)

--
-- other configration
--
config.use_ime = true

-- SSH_AUTH_SOCK を WezTerm に書き換えさせない。
-- 既定 (true) だと存在しない agent.<pid> を指す SSH_AUTH_SOCK が注入され、
-- Bitwarden の名前付きパイプ (\\.\pipe\openssh-ssh-agent) に繋がらなくなる。
config.mux_enable_ssh_agent = false

return config
