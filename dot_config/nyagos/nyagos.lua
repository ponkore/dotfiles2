return {
  init = function()

  require("fzf")
  require("zoxide")

  --
  -- 環境変数
  --
  nyagos.env.YAZI_FILE_ONE=nyagos.env.USERPROFILE .. "\\scoop\\apps\\git\\current\\usr\\bin\\file.exe"
  nyagos.env.HOME=nyagos.env.USERPROFILE

  -- 指定したパスがディレクトリであれば PATH 先頭に追加する
  -- nyagos.stat はバックスラッシュ区切りのパスを受け付けないためスラッシュで判定する
  local function prepend_path_if_dir(path)
    local st = nyagos.stat(path:gsub("\\", "/"))
    if type(st) == "table" and st.isdir then
      nyagos.env.PATH = path .. ";" .. nyagos.env.PATH
    end
  end

  -- OpenJDK (scoop) の bin が存在すれば PATH 先頭に追加
  prepend_path_if_dir(nyagos.env.USERPROFILE .. "\\scoop\\apps\\openjdk\\current\\bin")

  -- %USERPROFILE%\bin が存在すれば PATH 先頭に追加
  prepend_path_if_dir(nyagos.env.USERPROFILE .. "\\bin")

  -- %USERPROFILE%\.cargo\bin が存在すれば PATH 先頭に追加
  prepend_path_if_dir(nyagos.env.USERPROFILE .. "\\.cargo\\bin")

  -- nyagos.histsize (default: 1000)
  nyagos.histsize = 100000

  --
  -- alias
  --
  nyagos.alias.cat="bat"
  nyagos.alias.ls="lsd"
  nyagos.alias.rg="rg -p"
  nyagos.alias.less="less -R"
  nyagos.alias.psql="wsl psql"
  nyagos.alias.s="git status"
  nyagos.alias.di="git diff"
  nyagos.alias.zoom="wezterm cli zoom-pane --toggle"
  nyagos.alias.lg="lazygit"
  nyagos.alias.sql="sql -name ESC_Web2"  -- 実体は ~/bin/sql.cmd

  --
  -- prompt (starship)
  --
  local _isAdmin = (nyagos.eval("net session >nul 2>&1 && echo 1") or ""):match("1") ~= nil

  nyagos.prompt = function(this)
    if _isAdmin then
      prompt = "administrator@" .. nyagos.env.COMPUTERNAME 
      return nyagos.default_prompt("$e[49;31;1m"..prompt.."$e[37;1m" .. "$ ","")
    end
    local prompt = ""
    if nyagos.which("starship") then
      prompt = prompt .. nyagos.eval("starship prompt 2> nul") ..  "$e[37;1m" .. " "
    	return nyagos.default_prompt(prompt,"")
    end
    return nyagos.default_prompt("$e[49;36;1m"..this.."$e[37;1m","")
  end

  --
  -- ya: (cd after yazi) yazi を起動し、終了後にカレントディレクトリを yazi のディレクトリに合わせる
  --
  nyagos.alias.ya = function(args)
    local tmp = os.tmpname()
    nyagos.exec('yazi --cwd-file="' .. tmp .. '"')
    local f = io.open(tmp, "r")
    if f then
      local cwd = f:read("*l")
      f:close()
      if cwd and cwd ~= "" and cwd ~= nyagos.getwd() then
        nyagos.chdir(cwd)
      end
    end
    os.remove(tmp)
  end

  --
  -- claude: 引数なしで起動した場合、どの CLAUDE_CONFIG_DIR で起動するかを
  -- fzf メニューで選択させる（矢印キー+Enter、または数字キーで即決定）
  --
  local _claude_path = nyagos.which("claude") or "claude"

  local _claude_menu_items = {
    { label = "1) 通常起動(Claude Pro)",      config_dir = nil },
    { label = "2) jighead(Claude Max)",        config_dir = nyagos.env.USERPROFILE .. "\\.claude-config\\jighead" },
    { label = "3) ESC-Web(Claude Enterprise)", config_dir = nyagos.env.USERPROFILE .. "\\.claude-config\\ESC-Web" },
  }

  -- fzf で claude 起動方法を選択させ、選ばれた項目 (テーブル) を返す。
  -- キャンセル (Esc 等) の場合は nil を返す。
  local function _claude_select_menu()
    local tmp_menu = os.tmpname()
    local mf = io.open(tmp_menu, "w")
    for _, item in ipairs(_claude_menu_items) do
      mf:write(item.label .. "\n")
    end
    mf:close()

    local tmp_result = os.tmpname()
    local fzf_cmd = 'type "' .. tmp_menu .. '"'
      .. ' | fzf --prompt="claude> " --height=~40% --border'
      .. ' --header="[Up/Down + Enter] or [1-3] で選択"'
      .. ' --bind="1:pos(1)+accept,2:pos(2)+accept,3:pos(3)+accept"'
      .. ' > "' .. tmp_result .. '"'
    nyagos.exec(fzf_cmd)
    os.remove(tmp_menu)

    local rf = io.open(tmp_result, "r")
    local selection = rf and rf:read("*l") or nil
    if rf then rf:close() end
    os.remove(tmp_result)

    if not selection or selection == "" then
      return nil
    end
    for _, item in ipairs(_claude_menu_items) do
      if item.label == selection then
        return item
      end
    end
    return nil
  end

  nyagos.alias.claude = function(args)
    if #args > 0 then
      local cmd = '"' .. _claude_path .. '"'
      for _, v in ipairs(args) do
        cmd = cmd .. " " .. v
      end
      nyagos.exec(cmd)
      return
    end

    local chosen = _claude_select_menu()
    if not chosen then
      print("claude: キャンセルしました")
      return
    end

    local prev_config_dir = nyagos.env.CLAUDE_CONFIG_DIR
    nyagos.env.CLAUDE_CONFIG_DIR = chosen.config_dir

    nyagos.exec('"' .. _claude_path .. '"')

    nyagos.env.CLAUDE_CONFIG_DIR = prev_config_dir
  end

  --
  -- wezterm tab title 設定
  --
  nyagos.alias.tabtitle = function(args)
    if #args ~= 1 then
      print("Usage: tabtitle <title>")
      return
    end
    nyagos.exec("wezterm cli set-tab-title " .. args[1])
  end

end }
