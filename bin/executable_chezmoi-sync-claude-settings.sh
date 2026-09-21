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

# env.NODE_EXTRA_CA_CERTS は Windows でしか展開しない（modify_ スクリプト側で消す）。
# Windows 以外で取り込むと実ファイルに無いので source から消えてしまうため、
# source の値を引き継ぐ。
case "$(uname -s)" in
  MINGW* | MSYS* | CYGWIN*) filter='del(.autoMode)' ;;
  *) filter='del(.autoMode)
      | ($old[0].env.NODE_EXTRA_CA_CERTS // null) as $ca
      | if $ca == null or (.env.NODE_EXTRA_CA_CERTS != null) then .
        else . as $n
          | {env: ({NODE_EXTRA_CA_CERTS: $ca} + ($n.env // {}))} + ($n | del(.env))
        end' ;;
esac

# Windows の jq は常に CRLF を出力するため tr で LF に正規化する
jq --slurpfile old "$dst" "$filter" "$src" | tr -d '\r' > "$dst.tmp"
mv "$dst.tmp" "$dst"

echo "updated: $dst"
chezmoi diff "$src"
