-- exceldiff.yazi — Excel ファイルの差分を exceldiff で表示する
--
-- モード（第1引数）:
--   pair      選択した 2 ファイルを比較（一覧で上にある方が旧 = A）
--   pair-rev  同上、A/B を入れ替えて比較
--   vcs       git / svn のコミット済みリビジョンと作業コピーを比較
--   vcs-rev   同上、リビジョンを入力して比較
--
-- `--pane` を付けると WezTerm のペインを分割して実行し、ログとエラーを表示する。
-- 付けない場合はバックグラウンド起動（exceldiff は Excel を閉じるまで待つため、
-- block = true にすると yazi が固まる）。
--
-- 実行ファイルは環境変数 EXCELDIFF_BIN で上書きできる（既定は PATH 上の exceldiff）。

local EXTS = { xlsx = true, xlsm = true }

local function bin()
  return os.getenv("EXCELDIFF_BIN") or "exceldiff"
end

local function notify(message, level)
  ya.notify({
    title = "exceldiff",
    content = message,
    level = level or "error",
    timeout = 5,
  })
end

-- 選択があればそれを一覧の表示順で、なければ hover 中のファイルを返す。
local get_targets = ya.sync(function()
  local selected = {}
  local count = 0
  for _, it in pairs(cx.active.selected) do
    -- yazi のバージョンにより File / Url のどちらかが返る。
    local url = tostring(it.url or it)
    selected[url] = true
    count = count + 1
  end

  local urls = {}
  if count > 0 then
    -- 選択順ではなく一覧の表示順に並べる（上にある方を A = 旧とする）。
    for _, f in ipairs(cx.active.current.files) do
      local url = tostring(f.url)
      if selected[url] then
        urls[#urls + 1] = url
        selected[url] = nil
      end
    end
    -- 別ディレクトリで選択したものは表示順が決まらないので末尾に足す。
    for url in pairs(selected) do
      urls[#urls + 1] = url
    end
  else
    local hovered = cx.active.current.hovered
    if hovered and not hovered.cha.is_dir then
      urls[1] = tostring(hovered.url)
    end
  end
  return urls
end)

local get_cwd = ya.sync(function()
  local current = cx.active.current
  return current and current.cwd and tostring(current.cwd) or nil
end)

local function basename(path)
  return path:match("([^\\/]+)$") or path
end

local function is_excel(path)
  local ext = path:match("%.([^.\\/]+)$")
  return ext ~= nil and EXTS[ext:lower()] == true
end

-- PowerShell 用のシングルクォート。全体を ya.quote で包む前提のため、
-- ダブルクォートを一切含めないようにしている。
local function ps_quote(s)
  return "'" .. tostring(s):gsub("'", "''") .. "'"
end

-- exceldiff に渡す引数列をモードごとに組み立てる。
local function build_args(mode, urls)
  if mode == "vcs" or mode == "vcs-rev" then
    if #urls ~= 1 then
      return nil, "VCS 差分は 1 ファイルを指定してください（現在 " .. #urls .. " 件）"
    end
    local args = { "vcs" }
    if mode == "vcs-rev" then
      local rev, event = ya.input({
        title = "Revision (git: HEAD~1 / svn: BASE, 1234):",
        value = "HEAD~1",
        position = { "top-center", y = 3, w = 50 },
      })
      if event ~= 1 or not rev or rev:match("^%s*$") then
        return nil, nil -- 入力キャンセル。通知はしない。
      end
      args[#args + 1] = "-r"
      args[#args + 1] = rev
    end
    args[#args + 1] = urls[1]
    return args
  end

  if #urls ~= 2 then
    return nil, "2 つの Excel ファイルを選択してください（現在 " .. #urls .. " 件）"
  end
  local a, b = urls[1], urls[2]
  if mode == "pair-rev" then
    a, b = b, a
  end
  notify(string.format("A(旧): %s\nB(新): %s", basename(a), basename(b)), "info")
  return { a, b }
end

-- 方式 A: バックグラウンド起動（既定）。
local function run_detached(args)
  local parts = { ya.quote(bin()) }
  for _, a in ipairs(args) do
    parts[#parts + 1] = ya.quote(a)
  end
  ya.emit("shell", { table.concat(parts, " "), orphan = true })
end

-- 方式 B: WezTerm のペインで実行し、ログを表示する。失敗時はキー入力まで残す。
local function run_in_pane(args)
  if not os.getenv("WEZTERM_PANE") then
    notify("WEZTERM_PANE が設定されていません（--pane は WezTerm 上でのみ使えます）")
    return
  end
  local cwd = get_cwd()
  if not cwd then
    notify("カレントディレクトリを取得できません")
    return
  end

  local parts = { "&", ps_quote(bin()) }
  for _, a in ipairs(args) do
    parts[#parts + 1] = ps_quote(a)
  end
  local inner = string.format(
    "%s; if ($LASTEXITCODE -ne 0) { Read-Host %s }",
    table.concat(parts, " "),
    ps_quote("エラーが発生しました。Enter で閉じます")
  )

  local cmd = string.format(
    "wezterm cli split-pane --bottom --percent 40 --cwd %s -- pwsh -NoLogo -NoProfile -Command %s",
    ya.quote(cwd),
    ya.quote(inner)
  )
  ya.emit("shell", { cmd, orphan = true })
end

return {
  entry = function(_, job)
    local opts = job.args or {}
    local mode = opts[1] or "pair"
    local pane = opts.pane == true or opts[2] == "pane"

    local urls = get_targets()
    if #urls == 0 then
      return notify("対象のファイルがありません")
    end
    for _, url in ipairs(urls) do
      if not is_excel(url) then
        return notify("Excel ファイル（.xlsx / .xlsm）ではありません:\n" .. basename(url))
      end
    end

    local args, err = build_args(mode, urls)
    if not args then
      if err then
        notify(err)
      end
      return
    end

    if pane then
      run_in_pane(args)
    else
      run_detached(args)
    end
  end,
}
