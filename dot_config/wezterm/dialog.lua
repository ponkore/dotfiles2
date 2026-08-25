local wezterm = require 'wezterm'
local act = wezterm.action

--
-- 簡易メッセージダイアログ。
--
-- ペインの上にオーバーレイを重ねてメッセージを表示し、Enter でも Esc でも閉じる。
-- (InputSelector を選択肢 1 つ = OK だけで使っている)
--
-- 呼び出し方は 2 通り。
--
--   1. wezterm 内部から (keymap.lua など)
--        dialog.action { message = 'こんにちは' }   -- キーバインド用のアクション
--        dialog.show   { message = 'こんにちは' }   -- コールバックの中から直接
--
--   2. 外部プロセスから: OSC 1337 SetUserVar でユーザー変数 `dialog` を設定する
--      (workspace.lua の switch_workspace と同じ仕組み)。
--
--        printf "\033]1337;SetUserVar=dialog=%s\007" "$(printf 'メッセージ' | base64 -w0)"
--
--      値を `タイトル<US>本文` (US = 0x1f) にするとタブのタイトルを指定できる。
--      区切りが無ければ全体が本文。本文の改行はそのまま複数行として表示される。
--
--      なお hook のように標準出力がパイプに繋がれたプロセスからは OSC が届かない
--      (~/.claude/hooks/ 系)。その場合は wezterm cli spawn 経由で送ること。
--
local M = {}

-- 表示に使う GUI ウィンドウを決める。
-- user-var-changed はバックグラウンドのペインからも飛んでくるため、
-- window が nil のときはフォーカスのある GUI ウィンドウにフォールバックする。
local function resolve_window(window)
  if window ~= nil then return window end
  local windows = wezterm.gui.gui_windows()
  for _, w in ipairs(windows) do
    if w:is_focused() then return w end
  end
  return windows[1]
end

-- 改行で分割する (末尾の空行は落とす)
local function split_lines(text)
  local lines = {}
  for line in tostring(text or ''):gmatch '([^\n]*)\n?' do
    table.insert(lines, (line:gsub('\r$', '')))
  end
  while #lines > 0 and lines[#lines] == '' do
    table.remove(lines)
  end
  return lines
end

-- opts = {
--   message  = '本文 (改行可)',
--   title    = 'タブに出るタイトル',
--   ok_label = 'OK 行の文言',
--   window / pane = 表示先 (省略時はアクティブなウィンドウ・ペイン)
-- }
function M.show(opts)
  opts = opts or {}
  local win = resolve_window(opts.window)
  if win == nil then return end
  local pane = opts.pane or win:active_pane()

  local lines = split_lines(opts.message)

  -- 1 行目は description (オーバーレイ最上段)、2 行目以降は選択肢の行として並べる。
  -- description は 1 行しか描画されないため、複数行はこの形でしか出せない。
  local choices = {}
  for i = 2, #lines do
    table.insert(choices, { id = 'ok', label = lines[i] })
  end
  table.insert(choices, {
    id = 'ok',
    label = opts.ok_label or 'OK   -- Enter / Esc で閉じる',
  })

  win:perform_action(
    act.InputSelector {
      title = opts.title or 'Message',
      description = lines[1] or '',
      choices = choices,
      fuzzy = false,
      alphabet = '', -- 行頭の 1. 2. ... を出さない
      action = wezterm.action_callback(function() end), -- 閉じるだけ
    },
    pane
  )
end

-- キーバインドにそのまま置けるアクションを返す
function M.action(opts)
  return wezterm.action_callback(function(window, pane)
    local o = {}
    for k, v in pairs(opts or {}) do o[k] = v end
    o.window, o.pane = window, pane
    M.show(o)
  end)
end

-- 外部プロセスからの依頼 (OSC 1337 SetUserVar=dialog=<base64>)
wezterm.on('user-var-changed', function(window, pane, name, value)
  if name ~= 'dialog' then return end
  if value == nil or value == '' then return end

  -- "タイトル\31本文" 形式ならタイトルを切り出す (区切りが無ければ全体が本文)
  local title, message = value:match '^([^\31]-)\31(.*)$'
  if title == nil or title == '' then
    title, message = nil, value
  end

  M.show { window = window, pane = pane, title = title, message = message }
end)

function M.apply(_config)
  -- イベントハンドラの登録のみ。config への設定は無し。
end

return M
