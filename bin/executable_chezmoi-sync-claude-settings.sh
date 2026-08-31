#!/bin/sh
# ~/.claude-config/jighead/settings.json の管理対象キーを chezmoi source に取り込む。
#
# このファイルは modify_ スクリプトで管理しているため chezmoi re-add が効かない。
# hooks や modelSettings など autoMode 以外の設定を変更したら本スクリプトを実行する。
# autoMode は Claude Code が環境ごとに自動生成する項目なので取り込まない。
set -eu

src="$HOME/.claude-config/jighead/settings.json"
dst="$(chezmoi source-path)/.chezmoitemplates/claude-jighead-settings.json"

[ -f "$src" ] || { echo "not found: $src" >&2; exit 1; }

# Windows の jq は常に CRLF を出力するため tr で LF に正規化する
jq 'del(.autoMode)' "$src" | tr -d '\r' > "$dst.tmp"
mv "$dst.tmp" "$dst"

echo "updated: $dst"
chezmoi diff "$src"
