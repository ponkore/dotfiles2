local wezterm = require 'wezterm'
local act = wezterm.action

local M = {}

--
-- 外部プロセス(esc-web.ps1 など)からワークスペースを切り替えるための仕組み。
--
-- `wezterm cli` にはワークスペースを切り替えるサブコマンドが無いため、
-- OSC 1337 SetUserVar でユーザー変数 `switch_workspace` を設定してもらい、
-- その変更イベントを拾って SwitchToWorkspace を実行する。
--
--   printf "\033]1337;SetUserVar=switch_workspace=%s\007" "$(echo -n ESC_Web | base64)"
--
wezterm.on('user-var-changed', function(window, pane, name, value)
  if name ~= 'switch_workspace' then return end
  if window == nil or value == nil or value == '' then return end
  window:perform_action(act.SwitchToWorkspace { name = value }, pane)
end)

function M.apply(_config)
  -- イベントハンドラの登録のみ。config への設定は無し。
end

return M
