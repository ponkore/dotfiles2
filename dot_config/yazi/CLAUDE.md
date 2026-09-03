# CLAUDE.md

このファイルは、リポジトリ内のコードを扱う際に Claude Code (claude.ai/code) へ提供するガイダンスです。

## 概要

Windows 向け [Yazi](https://github.com/sxyazi/yazi) ファイルマネージャーの設定です。Yazi の設定ディレクトリは `%APPDATA%\yazi\config\` です。

## パッケージ管理

パッケージは `ya` CLI ツールで管理し、`package.toml` に宣言します：

```sh
ya pkg add <owner/repo>        # プラグインまたはフレーバーをインストール
ya pkg sync                    # インストール済みパッケージを package.toml に同期
```

インストール済みパッケージは `package.toml` の `rev` と `hash` で固定されます。パッケージ追加後は `ya pkg sync` を実行してロックファイルを更新してください。

## 設定ファイル

| ファイル | 用途 |
|----------|------|
| `yazi.toml` | マネージャーの動作、ファイルオープナー |
| `keymap.toml` | キーバインド（`[[mgr.prepend_keymap]]` でデフォルトを上書きせずに追加） |
| `theme.toml` | 有効なフレーバーの参照 |
| `init.lua` | プラグイン設定とカスタム Lua（Linemode、プラグイン `require`） |
| `package.toml` | 依存関係のロックファイル（プラグイン＋フレーバー） |

## 有効なプラグインとフレーバー

- **プラグイン**: `dedukun/bookmarks` — vi スタイルのディレクトリブックマーク（永続化なし。ブックマークデータは `%APPDATA%\yazi\state\.dds` に保存）
- **プラグイン**: `copy-git-relative-path`（ローカル、`plugins/copy-git-relative-path.yazi/`）— `c g` キーで Git リポジトリ内はルート相対、それ以外は絶対パスをコピー
- **プラグイン**: `goto-projects`（ローカル、`plugins/goto-projects.yazi/`）— `g p` キーで Projects ディレクトリへ移動。Windows では `C:/Projects`、それ以外では `~/Projects`
- **プラグイン**: `reveal-in-file-manager`（ローカル、`plugins/reveal-in-file-manager.yazi/`）— `E` キーで現在のディレクトリを OS のファイルマネージャーで開く。Windows では `explorer`、macOS では `open`（`uname -s` が `Darwin` の場合）。それ以外のプラットフォームではエラー通知
- **プラグイン**: `exceldiff`（ローカル、`plugins/exceldiff.yazi/`）— `X` プレフィックスで Excel ファイルの差分を [exceldiff](https://github.com/ponkore/exceldiff) に渡して表示。詳細は後述
- **フレーバー（有効）**: `catppuccin-mocha`（`theme.toml` の `[flavor] dark` で設定）
- **フレーバー（無効）**: `modus-vivendi`、`monokai`

## カスタム Linemode

`init.lua` で `size_and_mtime` というカスタム Linemode を定義しており、`yazi.toml` から使用されます：

```lua
function Linemode:size_and_mtime()
```

ファイル一覧にファイルサイズと更新日時を表示します。`yazi.toml` の `linemode` を変更した場合、この関数は使用されなくなります。

## Lua プラグイン API

yazi v25.5.28 以降、コマンド発行には `ya.emit()` を使用します（旧 `ya.mgr_emit()` は deprecated）：

```lua
ya.emit("cd", { dir })
```

外部プロセスの起動に `Command(...):spawn()` を使ってはいけません。返り値の `Child` を破棄した時点で子プロセスが kill されるため、`explorer` のように「起動してすぐ終了し、実処理を別プロセスへ引き渡す」コマンドは何も起きずに終わります。待ち受けが不要な場合でも `:status()`（または `:output()`）を使ってください。どちらも即座に返ります。

## ブックマークのキーバインド

`keymap.toml` で `b` プレフィックスを使って定義しています（プラグイン README のデフォルト `m`/`'` キーを上書き）：

| キー | 操作 |
|------|------|
| `b m` | 現在位置にブックマークを保存 |
| `b g` | ブックマークにジャンプ |
| `b d` | ブックマークを削除 |
| `b D` | すべてのブックマークを削除 |

## exceldiff プラグイン

`plugins/exceldiff.yazi/main.lua`。Excel ファイル（`.xlsx` / `.xlsm`）の差分を CLI ツール `exceldiff` に渡して表示します。

| キー | 操作 |
|------|------|
| `X d` | 選択した 2 ファイルを比較（**一覧で上にある方が旧＝A**） |
| `X D` | 同上、A/B を入れ替えて比較 |
| `X v` | git / svn のコミット済みリビジョン（git=HEAD / svn=BASE）と作業コピーを比較 |
| `X r` | 同上、リビジョンを入力して比較（`HEAD~1`、svn のリビジョン番号など） |
| `X P d` | `X d` を WezTerm のペインで実行（ログ・エラーを確認したいとき） |
| `X P v` | `X v` を WezTerm のペインで実行 |

- **`X` は yazi 既定の `unyank`（yank 状態の取り消し）を上書きしています。** yazi は既定で `Y` にも同じ `unyank` を割り当てているため、yank の取り消しは `Y`（または `Esc`）を使います。
- git / svn の判別とリビジョンの取り出しは `exceldiff vcs` 側が行うため、プラグインはファイルを渡すだけです。
- 起動は `ya.emit("shell", { cmd, orphan = true })`。`exceldiff` は Excel を閉じるまで待つため、`block = true` にすると yazi が固まります。
- `--pane` 付きのキーは `wezterm cli split-pane` でペインを分割し、`pwsh -Command` 経由で実行します（終了コードが 0 以外のときだけ `Read-Host` でペインを残す）。`WEZTERM_PANE` が未設定なら通知してエラー終了します。
- 実行ファイルは環境変数 `EXCELDIFF_BIN` で上書きできます。既定は PATH 上の `exceldiff`（現在は `~/bin/exceldiff.exe`）。

## フレーバーの切り替え

カラースキームを変更するには `theme.toml` を編集します：

```toml
[flavor]
dark = "catppuccin-mocha"   # または "modus-vivendi" または "monokai"
```

3つのフレーバーはすべて `flavors/` 以下にインストール済みです。
