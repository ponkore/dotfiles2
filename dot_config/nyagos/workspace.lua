if not nyagos then
    print("This is a script for nyagos not lua.exe")
    os.exit()
end

--
-- wezterm ワークスペースの切り替え / レイアウト構築
--
-- ~/.local/bin/ws.ps1 の処理を lua に移植したもの。pwsh の起動コスト（数百 ms）を
-- 払わずにワークスペースを切り替えるのが目的なので、fzf による選択メニューは持たない。
-- メニュー付きで選びたい場合は ws エイリアス（= ws.ps1）を使う。
--
--   - 対象ワークスペースが既に存在する場合はそのワークスペースへ移動するだけ。
--   - 存在しない場合はワークスペースを新規ウィンドウとして作成し、
--     その中に以下のレイアウトを構築してから移動する。
--       - 上下に分割（サイズ比 上:下 = 1:2）
--       - タブタイトルを環境ごとの title に設定
--       - 上ペイン: 作業ディレクトリで yazi を起動（終了すると nyagos に戻る）
--       - 下ペイン: 作業ディレクトリで nyagos を起動（フォーカスもこちら）
--
-- ワークスペースの切り替えは wezterm cli に該当サブコマンドが無いため、
-- OSC 1337 SetUserVar でユーザー変数 switch_workspace を設定し、
-- wezterm 側 (~/.config/wezterm/workspace.lua) のイベントハンドラに行わせる。
--
-- この仕組みには制約が 1 つある。user-var-changed イベントは、OSC を出した
-- ペインが GUI ウィンドウに載っているときにしか発火しない。1 度切り替えると
-- 元のワークスペースは GUI から外れるため、同じシェルから続けて
-- `RINSETSU && ESC_Web` のように実行しても、切り替わるのは最初の 1 回だけになる
-- (2 つ目もレイアウトの構築までは行われる)。切り替えられなかった場合は
-- その旨を表示するので Ctrl-t s などで移動すること。
--
-- パス中の \ をエスケープせずに書けるよう、パス文字列は [[...]] で記述する。
--

-- ---------------------------------------------------------------- 環境定義 --
local _environments = {
    {
        name           = "ESC_Web",
        workspace      = "ESC_Web",
        dir            = [[C:\Projects\ESC-Web\WebCoreSystem_v1]],
        title          = "ESC(main)",
        bottom_percent = 66,
    },
    {
        name           = "RINSETSU",
        workspace      = "RINSETSU",
        dir            = [[C:\Projects\nel\RINSETSU]],
        title          = "RINSETSU",
        bottom_percent = 66,
    },
    {
        name           = "config",
        workspace      = "config",
        dir            = nyagos.env.USERPROFILE .. [[\.config]],
        title          = "config",
        bottom_percent = 66,
    },
}

-- nyagos は .lua ファイルもコマンドとして検索するため、カレントディレクトリに
-- wezterm.lua があると wezterm コマンドの代わりに実行しようとしてしまう
-- （~/.config/wezterm/wezterm.lua がまさにそれ）。起動時にフルパスを解決して回避する。
local _wezterm = '"' .. (nyagos.which("wezterm") or "wezterm") .. '"'

local function q(s)
    -- 末尾の \ は "path\" となり closing quote がエスケープされるため除去する
    return '"' .. s:gsub([[\+$]], "") .. '"'
end

local function warn(msg)
    nyagos.write("ws: " .. msg .. "\n")
end

-- ------------------------------------------------------------------ base64 --
local _b64chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"

local function base64(s)
    local out = {}
    for i = 1, #s, 3 do
        local b1, b2, b3 = s:byte(i, i + 2)
        local n = b1 * 65536 + (b2 or 0) * 256 + (b3 or 0)
        local c1 = math.floor(n / 262144) % 64
        local c2 = math.floor(n / 4096) % 64
        local c3 = math.floor(n / 64) % 64
        local c4 = n % 64
        out[#out + 1] = _b64chars:sub(c1 + 1, c1 + 1)
            .. _b64chars:sub(c2 + 1, c2 + 1)
            .. (b2 and _b64chars:sub(c3 + 1, c3 + 1) or "=")
            .. (b3 and _b64chars:sub(c4 + 1, c4 + 1) or "=")
    end
    return table.concat(out)
end

-- ------------------------------------------------------------- wezterm cli --
local function wezterm_cli(args)
    return nyagos.eval(_wezterm .. " cli " .. args) or ""
end

local function cli_list()
    local lines = {}
    for line in wezterm_cli("list"):gmatch("[^\r\n]+") do
        lines[#lines + 1] = line
    end
    return lines
end

-- ワークスペースが存在するか (= そのワークスペースに属するペインが 1 つでもあるか)
--
-- `--format json` はペインタイトルの文字化けで JSON パースが失敗しうるため、
-- 既定のテーブル出力の先頭 4 列 (WINID TABID PANEID WORKSPACE) だけを見る。
local function workspace_exists(name)
    for _, line in ipairs(cli_list()) do
        if line:match("^%s*%d+%s+%d+%s+%d+%s+(%S+)%s") == name then
            return true
        end
    end
    return false
end

-- 現在 GUI に表示されているワークスペース名
-- list-clients の列: USER HOST PID CONNECTED IDLE WORKSPACE FOCUS [SSH_AUTH_SOCK]
local function focused_workspace()
    for line in wezterm_cli("list-clients"):gmatch("[^\r\n]+") do
        if not line:match("^USER%s") then
            local f = {}
            for w in line:gmatch("%S+") do f[#f + 1] = w end
            if #f >= 6 then return f[6] end
        end
    end
    return nil
end

-- OSC 1337 SetUserVar でワークスペース切り替えを wezterm 本体に依頼する。
-- nyagos.write ではなく io.write を使い、加工されない生のバイト列を端末へ流す。
--
-- 切り替えは非同期なので、実際に切り替わったかを list-clients で確認する。
-- nyagos の lua には sleep が無いため、wezterm cli の呼び出し自体
-- (1 回あたり数十 ms) をウェイト代わりにしてポーリングする。
local function switch_workspace(name)
    if focused_workspace() == name then return end
    io.write("\27]1337;SetUserVar=switch_workspace=" .. base64(name) .. "\7")
    io.stdout:flush()
    for _ = 1, 10 do
        if focused_workspace() == name then return end
    end
    warn(("%s へ自動で移動できませんでした (このペインは GUI に表示されていません)。"):format(name))
    warn("Ctrl-t s で移動してください。")
end

-- ------------------------------------------------------ レイアウト構築処理 --
local function build_layout(e)
    -- 上ペイン: nyagos 上で yazi を起動する (yazi 終了後は作業ディレクトリのまま nyagos に戻る)
    local top = wezterm_cli(("spawn --new-window --workspace %s --cwd %s -- %s --cmd-first yazi")
        :format(q(e.workspace), q(e.dir), q(nyagos.exe))):match("%d+")
    if not top then
        error("wezterm cli spawn に失敗しました", 0)
    end

    wezterm_cli(("set-tab-title --pane-id %s %s"):format(top, q(e.title)))

    -- 下ペイン(2/3)を作り nyagos を起動し、そちらへフォーカスする。
    --
    -- 新規ウィンドウは GUI に載るまで initial_cols x initial_rows のサイズのままだが、
    -- wezterm 側 (~/.config/wezterm/window.lua) でそれを実ウィンドウとほぼ同じ
    -- サイズにしてあるため、GUI に載る前に分割しても比率は崩れない。
    local bottom = wezterm_cli(("split-pane --pane-id %s --bottom --percent %d --cwd %s -- %s")
        :format(top, e.bottom_percent, q(e.dir), q(nyagos.exe))):match("%d+")
    if not bottom then
        error("wezterm cli split-pane に失敗しました", 0)
    end

    wezterm_cli("activate-pane --pane-id " .. bottom)

    -- レイアウトが出来上がってからワークスペースへ移動する
    switch_workspace(e.workspace)
end

local function open(name)
    local env
    for _, e in ipairs(_environments) do
        if e.name == name then env = e break end
    end
    if not env then
        warn("不明な環境名です: " .. tostring(name))
        return
    end

    if not nyagos.env.WEZTERM_PANE then
        warn("wezterm のペイン内で実行してください (WEZTERM_PANE が未設定です)。")
        return
    end

    -- 1. 既にワークスペースがあるなら移動するだけ
    if workspace_exists(env.workspace) then
        switch_workspace(env.workspace)
        return
    end

    -- 2. 無い場合はレイアウトを構築する
    -- nyagos.stat はバックスラッシュ区切りのパスを受け付けないためスラッシュに直す
    local st = nyagos.stat((env.dir:gsub([[\]], "/")))
    if type(st) ~= "table" or not st.isdir then
        warn("作業ディレクトリが見つかりません: " .. env.dir)
        return
    end
    if not nyagos.which("yazi") then
        warn("yazi が PATH 上に見つかりません。")
        return
    end

    -- wezterm cli spawn/split-pane の --cwd は実際には効かず、新しいペインの
    -- 作業ディレクトリは wezterm cli 実行時の環境変数 PWD から決まる。
    local prev_pwd = nyagos.env.PWD
    nyagos.env.PWD = env.dir
    local ok, err = pcall(build_layout, env)
    nyagos.env.PWD = prev_pwd

    if not ok then warn(tostring(err)) end
end

-- -------------------------------------------------------------- alias 登録 --
-- ESC_Web / RINSETSU / config: メニューを出さずに直接ワークスペースへ切り替える
for _, e in ipairs(_environments) do
    nyagos.alias[e.name] = function() open(e.name) end
end

-- ws: fzf で環境を選んでから開く (実体は ~/.local/bin/ws.ps1)
-- PATHEXT に .ps1 は含まれないため pwsh 経由で起動する
nyagos.alias.ws = 'pwsh -NoProfile -File "'
    .. nyagos.env.USERPROFILE .. [[\.local\bin\ws.ps1"]]
