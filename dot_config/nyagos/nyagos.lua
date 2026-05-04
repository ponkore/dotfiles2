return {
  init = function()

  require("fzf")
  require("zoxide")

  --
  -- 環境変数
  --
  nyagos.env.YAZI_FILE_ONE=nyagos.env.USERPROFILE .. "\\scoop\\apps\\git\\current\\usr\\bin\\file.exe"
  nyagos.env.HOME=nyagos.env.USERPROFILE

  -- nyagos.histsize (default: 1000)
  nyagos.histsize = 100000

  --
  -- alias
  --
  nyagos.alias.cat="bat"
  nyagos.alias.ls="lsd"
  nyagos.alias.rg="rg -p"
  nyagos.alias.less="less -R"
  nyagos.alias.rm="wsl rm"
  nyagos.alias.cp="wsl cp"
  nyagos.alias.mv="wsl mv"
  nyagos.alias.rsync="wsl rsync"
  nyagos.alias.psql="wsl psql"
  nyagos.alias.s="git status"
  nyagos.alias.di="git diff"
  nyagos.alias.zoom="wezterm cli zoom-pane --toggle"

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
  -- claude: ESC-Web 以下で実行する場合には CLAUDE_CONFIG_DIR を設定してから実行する
  --
  local _claude_path = nyagos.which("claude") or "claude"

  nyagos.alias.claude = function(args)
    local cwd = nyagos.getwd():gsub("\\", "/"):lower()
    local esc_web_prefix = "c:/projects/esc-web"

    local is_esc_web = (cwd == esc_web_prefix) or
                       (cwd:sub(1, #esc_web_prefix + 1) == esc_web_prefix .. "/")

    if is_esc_web then
      nyagos.env.CLAUDE_CONFIG_DIR = nyagos.env.USERPROFILE .. "\\.claude-config\\ESC-Web"
    end

    local cmd = '"' .. _claude_path .. '"'
    for _, v in ipairs(args) do
      cmd = cmd .. " " .. v
    end
    nyagos.exec(cmd)

    if is_esc_web then
      nyagos.env.CLAUDE_CONFIG_DIR = nil
    end
  end

  --
  -- wezterm tab title 設定
  --
  nyagos.alias.tabtitle = function(args)
    -- TODO: 引数が１つ以外の場合エラー
    nyagos.exec("wezterm cli set-tab-title " .. args[1])
  end

end }
