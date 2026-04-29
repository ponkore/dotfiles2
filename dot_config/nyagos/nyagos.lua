return {
  init = function()

  require("fzf")

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
  -- TODO: claude-wrapper: ESC-Web 以下で実行する場合には、環境変数 CLAUDE_CONFIG_DIR を設定する
  --
  nyagos.alias.claude_w = function()
  end

  --
  -- wezterm tab title 設定
  --
  nyagos.alias.tabtitle = function(args)
    -- TODO: 引数が１つ以外の場合エラー
    nyagos.exec("wezterm cli set-tab-title " .. args[1])
  end

end }
