local wezterm = require 'wezterm'
local act = wezterm.action
local mux = wezterm.mux

--
-- Claude Code からの通知 (タブタイトルの [WAIT] / [DONE] マーク) を扱う。
--
-- マークを付けるのは Claude Code の hook 側 (~/.claude/hooks/wezterm-notify.sh)。
-- こちらはマークの付いたタブを探して移動し、マークを消す役割だけを持つ。
-- ステータスラインもポーリングも使わない。
--
local M = {}

-- hook が元のタブタイトルを退避しておく場所 (hook 側と同じパス)
local STATE_DIR = wezterm.home_dir .. '/.local/state/wezterm-claude-notify'

local MARKS = { '[WAIT]', '[DONE]' }

-- タイトル先頭のマークを返す (無ければ nil)
local function mark_of(title)
  for _, m in ipairs(MARKS) do
    if title:sub(1, #m) == m then return m end
  end
  return nil
end

-- マークの付いたタブを集める。[WAIT] を先に、その中では tab_id 順に並べる。
local function pending()
  local list = {}
  for _, win in ipairs(mux.all_windows()) do
    local ws = win:get_workspace()
    for _, tab in ipairs(win:tabs()) do
      local title = tab:get_title() or ''
      local mark = mark_of(title)
      if mark then
        table.insert(list, {
          tab = tab,
          tab_id = tab:tab_id(),
          workspace = ws,
          title = title,
          mark = mark,
        })
      end
    end
  end
  table.sort(list, function(a, b)
    if a.mark ~= b.mark then return a.mark == '[WAIT]' end
    return a.tab_id < b.tab_id
  end)
  return list
end

-- マークを消して元のタブタイトルに戻す
local function clear(tab)
  local path = STATE_DIR .. '/tab-' .. tostring(tab:tab_id())
  local original = ''
  local f = io.open(path, 'r')
  if f then
    original = f:read('*a') or ''
    f:close()
    os.remove(path)
  else
    -- 退避ファイルが無い場合はマーク部分だけを取り除く
    local title = tab:get_title() or ''
    local m = mark_of(title)
    if m then original = title:sub(#m + 2) end
  end
  tab:set_title(original)
end

-- そのタブへ移動してマークを消す
local function goto_entry(window, pane, entry)
  entry.tab:activate()
  if entry.workspace ~= mux.get_active_workspace() then
    window:perform_action(act.SwitchToWorkspace { name = entry.workspace }, pane)
  end
  clear(entry.tab)
end

-- 先頭の通知へジャンプする ([WAIT] を優先)
M.jump_next = wezterm.action_callback(function(window, pane)
  local list = pending()
  if #list == 0 then
    window:toast_notification('wezterm', 'Claude からの通知はありません', nil, 2000)
    return
  end
  goto_entry(window, pane, list[1])
end)

-- 通知の一覧から選んでジャンプする
M.select = wezterm.action_callback(function(window, pane)
  local list = pending()
  if #list == 0 then
    window:toast_notification('wezterm', 'Claude からの通知はありません', nil, 2000)
    return
  end

  local by_id = {}
  local choices = {}
  for _, e in ipairs(list) do
    by_id[tostring(e.tab_id)] = e
    table.insert(choices, {
      id = tostring(e.tab_id),
      label = string.format('%s  %s', e.workspace, e.title),
    })
  end

  window:perform_action(
    act.InputSelector {
      title = 'Claude notifications',
      choices = choices,
      fuzzy = true,
      fuzzy_description = 'Notification: ',
      action = wezterm.action_callback(function(win, p, id, _)
        local entry = id and by_id[id]
        if entry then goto_entry(win, p, entry) end
      end),
    },
    pane
  )
end)


function M.apply(_config)
  -- config への設定は無し (キーバインドは keymap.lua 側で割り当てる)
end

return M
