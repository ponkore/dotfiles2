# nyagos 設定

nyagos（Windows 向けシェル）の Lua 設定ファイル群。

## ファイル構成

```
~/.nyagos.lua               # nyagos 起動時に読み込まれるエントリーポイント
~/.config/nyagos/
  nyagos.lua                # メイン設定ファイル（~/.nyagos.lua から呼び出される）
  CLAUDE.md                 # このファイル
```

### エントリーポイントの仕組み

`~/.nyagos.lua` は nyagos 起動時に自動読み込みされ、以下のように `~/.config/nyagos/nyagos.lua` をモジュールとして呼び出す：

```lua
local home = nyagos.env.HOME or nyagos.env.USERPROFILE
package.path = package.path .. ";" .. home .. "\\.config\\nyagos\\?.lua"
require("nyagos").init()
```

`nyagos.lua` はモジュール形式（`return { init = function() ... end }`）で記述されており、`init()` が実際の設定処理を行う。

## 設定内容

### 環境変数

| 変数 | 値 |
|------|----|
| `HOME` | `%USERPROFILE%` と同値に設定（WSL 連携用） |
| `YAZI_FILE_ONE` | scoop 経由でインストールした Git の `file.exe` を指定 |

### エイリアス

| エイリアス | 実体 | 用途 |
|-----------|------|------|
| `cat` | `bat` | シンタックスハイライト付き cat |
| `ls` | `lsd` | アイコン付き ls |
| `rg` | `rg -p` | ページャー対応 ripgrep |
| `less` | `less -R` | ANSI カラー対応 less |
| `rm` / `cp` / `mv` / `rsync` | `wsl <cmd>` | WSL 経由で実行 |
| `psql` | `wsl psql` | WSL 経由で実行 |
| `s` | `git status` | |
| `di` | `git diff` | |
| `zoom` | `wezterm cli zoom-pane --toggle` | WezTerm ペインのズーム切り替え |

### 関数型エイリアス

#### `ya` — yazi ファイルマネージャー起動

yazi 終了後に、yazi 内で移動したディレクトリへシェルの cwd を同期する。

#### `claude` — プロジェクト別設定付き Claude Code 起動

カレントディレクトリが `C:/Projects/ESC-Web` 以下の場合、環境変数 `CLAUDE_CONFIG_DIR` を
`%USERPROFILE%\.claude-config\ESC-Web` に設定してから claude を実行し、終了後に unset する。
それ以外のディレクトリではそのまま実行。

再帰呼び出しを避けるため、nyagos 起動時に `nyagos.which("claude")` でフルパスを解決して実行する。

#### `tabtitle` — WezTerm タブタイトル設定

引数に指定した文字列を WezTerm の現在タブのタイトルに設定する。

### プロンプト

- 管理者権限の場合：`administrator@<COMPUTERNAME>$`（赤色）
- starship がインストール済みの場合：starship によるプロンプト
- その他：シアン色のデフォルトプロンプト

## ファイル管理

このディレクトリは **chezmoi** で管理されている。

- chezmoi ソース: `~/.local/share/chezmoi/dot_config/nyagos/`
- `nyagos.lua` を編集したら chezmoi ソースにも同じ変更を反映すること

```
# 編集後にソースへ取り込む場合
chezmoi add ~/.config/nyagos/nyagos.lua
```

## 設定の反映

nyagos の設定変更を反映するには nyagos を再起動する（設定ファイルのホットリロードは未対応）。
