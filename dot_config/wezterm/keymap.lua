local wezterm = require 'wezterm'
local act = wezterm.action

local M = {}

function M.apply(config)
  config.leader = { key = 't', mods = 'CTRL', timeout_milliseconds = 1000 }
  config.keys = {
    { key = 'Enter', mods = 'SHIFT',        action = wezterm.action.SendString('\x1b[13;2u')}, -- claude に SHIFT+Enter を送る
    { key = 'Enter', mods = 'CTRL|SHIFT',   action = wezterm.action.SendString('\x1b[13;2u')}, -- claude に SHIFT+Enter を送る
    { key = 'c',     mods = 'LEADER',       action = act.SpawnTab 'CurrentPaneDomain' },
    { key = '"',     mods = 'LEADER|SHIFT', action = act.SplitVertical { domain = 'CurrentPaneDomain' }},
    { key = '%',     mods = 'LEADER|SHIFT', action = act.SplitHorizontal { domain = 'CurrentPaneDomain' }},
    { key = 'o',     mods = 'LEADER',       action = act.ActivatePaneDirection 'Next' },
    { key = ';',     mods = 'LEADER',       action = act.ActivatePaneDirection 'Prev' },
    { key = 'o',     mods = 'LEADER|CTRL',  action = act.RotatePanes 'Clockwise' },
    { key = 's',     mods = 'LEADER',       action = act.ShowLauncherArgs { flags = 'WORKSPACES', title = 'Select workspace' } },
    { key = 'z',     mods = 'LEADER',       action = act.TogglePaneZoomState },
    { key = 'x',     mods = 'LEADER',       action = act.ActivateCopyMode },
  }
end

return M
