local wezterm = require 'wezterm'
local mux = wezterm.mux

--
-- ウィンドウタイトルの書式を決める。
--
-- 既定のタイトル (アクティブペインのタイトル) の先頭に、そのウィンドウの
-- ワークスペース名を `[名前] ` の形で足す。
--
-- format-window-title を登録すると、ペインが出す OSC 2 や
-- `wezterm cli set-window-title` よりこちらが優先されるので、
-- Claude Code などがタイトルを書き換えても接頭辞は消えない。
--
local M = {}

-- tab が属するウィンドウのワークスペース名を返す。
-- ウィンドウごとにワークスペースが違うため mux.get_active_workspace() は使えない
-- (フォーカスの無いウィンドウまでアクティブなワークスペース名になってしまう)。
local function workspace_of(tab)
  local win = tab.window_id and mux.get_window(tab.window_id)
  return win and win:get_workspace() or nil
end

wezterm.on('format-window-title', function(tab, _pane, _tabs, _panes, _config)
  local prefix = ''
  local ok, ws = pcall(workspace_of, tab)
  if ok and ws and ws ~= '' then
    prefix = '[' .. ws .. '] '
  end
  return prefix .. (tab.active_pane.title or '')
end)

function M.apply(_config)
  -- イベントハンドラの登録のみ。config への設定は無し。
end

return M
