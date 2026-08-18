local wezterm = require 'wezterm'
local act = wezterm.action
local mux = wezterm.mux
local notification = require 'notification'

local M = {}

-- 現在のワークスペース名をリネームする
local rename_workspace = act.PromptInputLine {
  description = 'Rename workspace:',
  action = wezterm.action_callback(function(_, _, line)
    -- ESC でキャンセルした場合は line が nil
    if line and line ~= '' then
      mux.rename_workspace(mux.get_active_workspace(), line)
    end
  end),
}

-- 名前を指定してワークスペースを作成する (既存名の場合はそのワークスペースへ移動)
local create_workspace = act.PromptInputLine {
  description = 'Create workspace:',
  action = wezterm.action_callback(function(win, pane, line)
    if line and line ~= '' then
      win:perform_action(act.SwitchToWorkspace { name = line }, pane)
    end
  end),
}

-- ワークスペースを一覧表示し、選択したものに移動する
-- 名前順に 1. 2. ... と番号を振り、現在のワークスペースには * を付ける
local switch_workspace = wezterm.action_callback(function(window, pane)
  local active = mux.get_active_workspace()
  local names = mux.get_workspace_names()
  table.sort(names)

  local choices = {}
  for i, name in ipairs(names) do
    table.insert(choices, {
      id = name,
      label = string.format('%d. %s%s', i, name, (name == active) and ' *' or ''),
    })
  end
  window:perform_action(
    act.InputSelector {
      title = 'Select workspace',
      choices = choices,
      fuzzy = true,
      fuzzy_description = 'Workspace: ',
      action = wezterm.action_callback(function(win, p, id, _)
        if id then
          win:perform_action(act.SwitchToWorkspace { name = id }, p)
        end
      end),
    },
    pane
  )
end)

function M.apply(config)
  config.leader = { key = 't', mods = 'CTRL', timeout_milliseconds = 1000 }
  config.keys = {
    { key = 'Enter', mods = 'SHIFT',        action = wezterm.action.SendString('\x1b[13;2u')}, -- claude に SHIFT+Enter を送る
    { key = 'Enter', mods = 'CTRL|SHIFT',   action = wezterm.action.SendString('\x1b[13;2u')}, -- claude に SHIFT+Enter を送る
    { key = 'c',     mods = 'LEADER',       action = act.SpawnTab 'CurrentPaneDomain' },
    { key = 'n',     mods = 'LEADER',       action = act.SpawnWindow },
    { key = '"',     mods = 'LEADER|SHIFT', action = act.SplitVertical { domain = 'CurrentPaneDomain' }},
    { key = '%',     mods = 'LEADER|SHIFT', action = act.SplitHorizontal { domain = 'CurrentPaneDomain' }},
    { key = 'o',     mods = 'LEADER',       action = act.ActivatePaneDirection 'Next' },
    { key = ';',     mods = 'LEADER',       action = act.ActivatePaneDirection 'Prev' },
    { key = 'o',     mods = 'LEADER|CTRL',  action = act.RotatePanes 'Clockwise' },
    { key = 's',     mods = 'LEADER',       action = switch_workspace },
    { key = 'S',     mods = 'LEADER|SHIFT', action = create_workspace },
    { key = '$',     mods = 'LEADER|SHIFT', action = rename_workspace },
    { key = 'z',     mods = 'LEADER',       action = act.TogglePaneZoomState },
    { key = 'x',     mods = 'LEADER',       action = act.ActivateCopyMode },
    { key = 'f',     mods = 'LEADER',       action = act.EmitEvent 'fit-window-to-workarea' },
    -- Claude Code からの通知 ([WAIT] / [DONE] の付いたタブ) へ移動する
    { key = 'u',     mods = 'LEADER',       action = notification.select },
    { key = 'g',     mods = 'LEADER',       action = notification.jump_next },
  }
end

return M
