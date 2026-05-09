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
- **プラグイン**: `goto-projects`（ローカル、`plugins/goto-projects.yazi/`）— `g p` キーで Projects ディレクトリへ移動。Windows では `C:/Projects`、それ以外では `~/Projects`
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

## ブックマークのキーバインド

`keymap.toml` で `b` プレフィックスを使って定義しています（プラグイン README のデフォルト `m`/`'` キーを上書き）：

| キー | 操作 |
|------|------|
| `b m` | 現在位置にブックマークを保存 |
| `b g` | ブックマークにジャンプ |
| `b d` | ブックマークを削除 |
| `b D` | すべてのブックマークを削除 |

## フレーバーの切り替え

カラースキームを変更するには `theme.toml` を編集します：

```toml
[flavor]
dark = "catppuccin-mocha"   # または "modus-vivendi" または "monokai"
```

3つのフレーバーはすべて `flavors/` 以下にインストール済みです。
