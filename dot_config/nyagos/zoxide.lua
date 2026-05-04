if not nyagos then
    print("This is a script for nyagos not lua.exe")
    os.exit()
end

local _zoxide_prefix = "z#"

-- OLDPWD 追跡: hook.chdir は移動後に呼ばれるため、2変数で管理する
-- _zoxide_curdir: フックが前回受け取った newdir（= 現在地の追跡）
-- _zoxide_oldpwd: z - で戻るための前のディレクトリ
local _zoxide_curdir = nyagos.getwd()
local _zoxide_oldpwd = nyagos.getwd()

local function q(path)
    -- 末尾の \ は "path\" となり closing quote がエスケープされるため除去する
    return '"' .. path:gsub("\\+$", "") .. '"'
end

local function zoxide_cd(path)
    path = path:match("^(.-)%s*$")
    if path == "" then return end
    local ok, err = nyagos.chdir(path)
    if ok then
        -- hook.chdir は nyagos.chdir() 呼び出しでは発火しないため直接登録する
        -- chdir 後に getwd() で絶対パスを取得する（相対パス引数でも正しく記録できる）
        local abspath = nyagos.getwd()
        _zoxide_oldpwd = _zoxide_curdir
        _zoxide_curdir = abspath
        nyagos.eval("zoxide add -- " .. q(abspath) .. " 2> nul")
    else
        nyagos.write("zoxide: " .. (err or "chdir failed: " .. path) .. "\n")
    end
end

-- =============================================================================
-- chdir フック: ディレクトリ移動後に zoxide add を呼ぶ
-- =============================================================================

if not nyagos.hook then nyagos.hook = {} end
local _prev_chdir_hook = nyagos.hook.chdir
nyagos.hook.chdir = function(newdir)
    _zoxide_oldpwd = _zoxide_curdir    -- 前のディレクトリを保存（z - 用）
    _zoxide_curdir = newdir            -- 現在地の追跡を更新
    nyagos.eval("zoxide add -- " .. q(newdir) .. " 2> nul")
    if _prev_chdir_hook then _prev_chdir_hook(newdir) end
end

-- =============================================================================
-- z コマンド
-- =============================================================================

nyagos.alias.z = function(args)
    local argc = #args

    if argc == 0 then
        zoxide_cd(nyagos.env.HOME or nyagos.env.USERPROFILE)
        return
    end

    if argc == 1 and args[1] == "-" then
        if _zoxide_oldpwd and _zoxide_oldpwd ~= "" then
            zoxide_cd(_zoxide_oldpwd)
        else
            nyagos.write("zoxide: OLDPWD not set\n")
        end
        return
    end

    if argc == 2 and args[1] == "--" then
        zoxide_cd(args[2])
        return
    end

    local last_arg = args[argc]
    if last_arg:sub(1, #_zoxide_prefix) == _zoxide_prefix then
        zoxide_cd(last_arg:sub(#_zoxide_prefix + 1))
        return
    end

    if argc == 1 then
        local stat = nyagos.stat(args[1])
        if stat and stat.isdir then
            zoxide_cd(args[1])
            return
        end
    end

    local cwd = nyagos.getwd()
    local keywords = table.concat(args, " ", 1, argc)
    local result = nyagos.eval(
        "zoxide query --exclude " .. q(cwd) .. " -- " .. keywords .. " 2> nul"
    )
    if result and result:match("%S") then
        zoxide_cd(result)
    else
        nyagos.write("zoxide: no match found for: " .. keywords .. "\n")
    end
end

-- =============================================================================
-- zi コマンド（fzf インタラクティブ選択）
-- =============================================================================

nyagos.alias.zi = function(args)
    local keywords = table.concat(args, " ", 1, #args)
    local cmd = "zoxide query --list"
    if keywords ~= "" then
        cmd = cmd .. " -- " .. keywords
    end
    cmd = cmd .. " 2> nul | fzf"

    local result = nyagos.eval(cmd)
    if result and result:match("%S") then
        zoxide_cd(result)
    end
end
