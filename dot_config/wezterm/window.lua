local wezterm = require 'wezterm'

local M = {}

local is_windows = wezterm.target_triple:find('windows') ~= nil

-- 起動時のウィンドウ幅(桁数)
--   nil    : 直前に使っていた桁数を再現する (リサイズするたびに記録される)
--   数値   : その桁数に固定する
M.columns = nil
M.default_columns = 145 -- 記録がまだ無いときに使う桁数

-- PowerShell から情報が取れなかったときのフォールバック値
M.fallback_taskbar_height = 48 -- 下端タスクバーの高さ
M.fallback_caption_height = 31 -- OS タイトルバー + 上端リサイズ枠

-- 作業領域(タスクバーを除いた矩形)とウィンドウ枠の寸法を問い合わせる。
--   metrics <caption> <border>
--   screen  <bounds x y w h> <workarea x y w h>
local PS_SCRIPT = [==[
Add-Type -Namespace WezWin -Name Sys -MemberDefinition '
[DllImport("user32.dll")] public static extern int GetSystemMetrics(int i);
[DllImport("user32.dll")] public static extern bool SetProcessDPIAware();
'
[void][WezWin.Sys]::SetProcessDPIAware()
Add-Type -AssemblyName System.Windows.Forms
'metrics {0} {1}' -f ([WezWin.Sys]::GetSystemMetrics(4) + [WezWin.Sys]::GetSystemMetrics(33) + [WezWin.Sys]::GetSystemMetrics(92)), [WezWin.Sys]::GetSystemMetrics(5)
foreach ($s in [System.Windows.Forms.Screen]::AllScreens) {
  $b = $s.Bounds; $w = $s.WorkingArea
  'screen {0} {1} {2} {3} {4} {5} {6} {7}' -f $b.X, $b.Y, $b.Width, $b.Height, $w.X, $w.Y, $w.Width, $w.Height
}
]==]

local STATE_DIR = wezterm.home_dir .. '/.local/share/wezterm'
local CACHE_PATH = STATE_DIR .. '/workarea-cache.txt'
local COLUMNS_PATH = STATE_DIR .. '/window-columns.txt'

local function read_file(path)
  local f = io.open(path, 'r')
  if not f then return nil end
  local body = f:read('*a')
  f:close()
  return body
end

local function write_file(path, body)
  local f = io.open(path, 'w')
  if not f then return end
  f:write(body)
  f:close()
end

--
-- 作業領域の取得 (PowerShell の起動は 0.5 秒ほどかかるので、
-- ディスプレイ構成が変わらない限り結果を使い回す)
--

local function layout_signature()
  local keys = {}
  for name, s in pairs(wezterm.gui.screens().by_name) do
    keys[#keys + 1] = string.format('%s:%d,%d,%dx%d@%s', name, s.x, s.y, s.width, s.height, tostring(s.scale))
  end
  table.sort(keys)
  return table.concat(keys, '|')
end

local function parse(raw)
  local info = { screens = {} }
  for line in raw:gmatch('[^\r\n]+') do
    if line:sub(1, 7) == 'metrics' then
      local caption, border = line:match('^metrics (%d+) (%d+)')
      info.caption, info.border = tonumber(caption), tonumber(border)
    elseif line:sub(1, 6) == 'screen' then
      local n = {}
      for v in line:gmatch('%-?%d+') do n[#n + 1] = tonumber(v) end
      if #n == 8 then
        info.screens[#info.screens + 1] = {
          bounds = { x = n[1], y = n[2], width = n[3], height = n[4] },
          work = { x = n[5], y = n[6], width = n[7], height = n[8] },
        }
      end
    end
  end
  if info.caption and info.border and #info.screens > 0 then return info end
  return nil
end

local function desktop_info()
  local sig = layout_signature()
  local cached = read_file(CACHE_PATH)
  if cached then
    local head, rest = cached:match('^([^\n]*)\n(.*)$')
    if head == sig then
      local info = parse(rest)
      if info then return info end
    end
  end
  local ok, stdout, stderr = wezterm.run_child_process({
    'powershell.exe', '-NoProfile', '-NonInteractive', '-NoLogo', '-Command', PS_SCRIPT,
  })
  if not ok then
    wezterm.log_error('window.lua: failed to query work area: ' .. tostring(stderr))
    return nil
  end
  local info = parse(stdout)
  if info then write_file(CACHE_PATH, sig .. '\n' .. stdout) end
  return info
end

--
-- 幅(桁数)の記録
--

local function remembered_columns()
  local body = read_file(COLUMNS_PATH)
  return body and tonumber(body:match('%d+'))
end

local function remember_columns(cols)
  if cols and cols > 0 then write_file(COLUMNS_PATH, tostring(cols)) end
end

--
-- 本体
--

-- gui_window を「作業領域の高さ・指定桁数の幅・ディスプレイ右端」に合わせる。
-- has_title_bar は OS タイトルバーの有無 (window_decorations 由来)。
-- pane を省略した場合はアクティブなペインを使う。
function M.fit(gui, has_title_bar, pane)
  if not is_windows then return end

  local screen = wezterm.gui.screens().active
  local info = desktop_info()
  local work, caption, border

  if info then
    for _, s in ipairs(info.screens) do
      if s.bounds.x == screen.x and s.bounds.y == screen.y
          and s.bounds.width == screen.width and s.bounds.height == screen.height then
        work = s.work
        break
      end
    end
    caption, border = info.caption, info.border
  end

  if not work then
    work = {
      x = screen.x,
      y = screen.y,
      width = screen.width,
      height = screen.height - M.fallback_taskbar_height,
    }
    caption, border = M.fallback_caption_height, 1
  end

  if not has_title_bar then caption = 0 end

  local dims = gui:get_dimensions()

  -- 幅: 桁数 x セル幅 + 左右パディング。セル幅とパディングは現在のペインから逆算する。
  local width = dims.pixel_width
  pane = pane or gui:active_pane()
  local pdims = pane and pane:get_dimensions()
  if pdims and pdims.cols and pdims.cols > 0 then
    local cell_width = pdims.pixel_width / pdims.cols
    local padding = dims.pixel_width - pdims.pixel_width
    local cols = M.columns or remembered_columns() or M.default_columns
    width = math.floor(cols * cell_width + padding + 0.5)
  end

  local height = work.height - caption - border

  -- set_inner_size / set_position はどちらもクライアント領域 (枠の内側) 基準
  gui:set_inner_size(width, height)
  gui:set_position(work.x + work.width - border - width, work.y + caption)
end

function M.apply(config)
  -- macOS では PowerShell が無いので何もしない (別途対応予定)
  if not is_windows then return end

  local has_title_bar = true
  local ok, deco = pcall(function() return config.window_decorations end)
  if ok and type(deco) == 'string' then
    has_title_bar = deco:upper():find('TITLE') ~= nil
  end

  wezterm.on('gui-startup', function(cmd)
    local _, pane, window = wezterm.mux.spawn_window(cmd or {})
    local gui = window:gui_window()
    local fitted, err = pcall(M.fit, gui, has_title_bar, pane)
    if not fitted then
      wezterm.log_error('window.lua: fit failed: ' .. tostring(err))
    end
  end)

  -- キーバインドから呼び出す用: act.EmitEvent 'fit-window-to-workarea'
  wezterm.on('fit-window-to-workarea', function(gui, pane)
    pcall(M.fit, gui, has_title_bar, pane)
  end)

  -- 手でリサイズした桁数を次回の起動幅として覚えておく (M.columns が nil のとき)
  if M.columns == nil then
    wezterm.on('window-resized', function(gui, pane)
      local d = gui:get_dimensions()
      if d and d.is_full_screen then return end
      local pd = pane and pane:get_dimensions()
      if pd then remember_columns(pd.cols) end
    end)
  end
end

return M
