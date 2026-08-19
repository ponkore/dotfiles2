# nyagos 設定

nyagos（Windows 向けシェル）の Lua 設定ファイル群。

## ファイル構成

```
~/.nyagos.lua               # nyagos 起動時に読み込まれるエントリーポイント
~/.config/nyagos/
  nyagos.lua                # メイン設定ファイル（~/.nyagos.lua から呼び出される）
  workspace.lua             # WezTerm ワークスペース切替（nyagos.lua から require）
  zoxide.lua                # zoxide 連携（nyagos.lua から require）
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
| `lg` | `lazygit` | lazygit 起動 |
| `ESC_Web` / `RINSETSU` / `config` | workspace.lua の lua 実装 | WezTerm ワークスペースへ直接切り替える |
| `ws` | `pwsh -NoProfile -File ~/.local/bin/ws.ps1` | fzf で選んで WezTerm ワークスペースを開く |

#### `ESC_Web` / `RINSETSU` / `config` — WezTerm ワークスペース切替（lua 実装）

`workspace.lua` の lua 実装で、fzf メニューを出さずに指定ワークスペースへ直接切り替える。
pwsh の起動コスト（約 1 秒）が無くなり、既存ワークスペースへの移動は `wezterm cli list`
1 回分（数十 ms）で済む。

- 対象ワークスペースが既に存在する場合はそこへ移動するだけ
- 存在しない場合は新規ウィンドウとして作成し、上下 1:2 分割（上ペイン yazi / 下ペイン
  nyagos、フォーカスは下）を構築してから移動する

環境定義（作業ディレクトリ・タブタイトル・分割比）は `workspace.lua` 冒頭の
`_environments` にまとまっている。環境を増やすとその名前の alias が自動的に登録される。

ワークスペースの切り替えは `wezterm cli` に該当サブコマンドが無いため、OSC 1337
SetUserVar でユーザー変数 `switch_workspace` を設定し、WezTerm 側
（`~/.config/wezterm/workspace.lua`）のイベントハンドラに行わせる。OSC は加工されない
生のバイト列を流す必要があるため `nyagos.write` ではなく `io.write` を使う。

実装上の注意:

- パス中の `\` をエスケープせずに書けるよう、パス文字列は `[[...]]` で記述する
- `wezterm` は起動時に `nyagos.which` でフルパスを解決する。カレントディレクトリに
  `wezterm.lua` があると（`~/.config/wezterm/` がまさにそれ）nyagos がそちらを
  コマンドとして実行してしまうため
- nyagos の lua には sleep が無いため、新規ウィンドウが実サイズになるのを待つ処理は
  `wezterm cli list` の呼び出し自体（1 回あたり数十 ms）をウェイト代わりにポーリングする
- `wezterm cli spawn` / `split-pane` の `--cwd` は実際には効かず、新しいペインの作業
  ディレクトリは実行時の環境変数 `PWD` から決まるため、呼び出し前後で `PWD` を差し替える

#### `ws` — WezTerm ワークスペースを fzf で選んで開く

`~/.local/bin/ws.ps1` を pwsh 経由で呼び出す。`PATHEXT` に `.ps1` が含まれないため、
`pwsh -NoProfile -File` でフルパス指定して起動する。

引数なしなら fzf メニュー（Up/Down + Enter、または数字キーで即決定）、`ws RINSETSU` の
ように環境名を渡せばメニューを出さずに開く。`-Dir` / `-Workspace` / `-Title` /
`-BottomPercent` / `-FocusTop` で環境定義を上書きできるのも ws.ps1 側だけの機能。

### 関数型エイリアス

#### `ya` — yazi ファイルマネージャー起動

yazi 終了後に、yazi 内で移動したディレクトリへシェルの cwd を同期する。

#### `claude` — 設定選択メニュー付き Claude Code 起動

引数なしで実行した場合、fzf によるメニューで起動方法を選択させる（Up/Down + Enter、または
数字キー 1〜3 で即決定）。

| 選択肢 | タイトル | `CLAUDE_CONFIG_DIR` |
|--------|----------|----------------------|
| 1 | 通常起動(Claude Pro) | 設定しない |
| 2 | jighead(Claude Max) | `%USERPROFILE%\.claude-config\jighead` |
| 3 | ESC-Web(Claude Enterprise) | `%USERPROFILE%\.claude-config\ESC-Web` |

選択した環境変数を設定してから claude を実行し、終了後に元の値へ戻す（キャンセル時は何もせず終了）。
引数付きで実行した場合（例: `claude --version`）はメニューを出さず、環境変数を変更せずにそのまま実行する。

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
