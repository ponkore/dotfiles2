#!/usr/bin/env bash
#
# Claude Code の状態を WezTerm のタブタイトルとデスクトップトーストで知らせる。
#
#   wezterm-notify.sh waiting   … 入力待ち   → タブに [WAIT] を付け、トーストを出す
#   wezterm-notify.sh done      … 応答完了   → タブに [DONE] を付ける
#   wezterm-notify.sh clear     … マーク解除 → 元のタブタイトルに戻す
#
# 元のタブタイトルは ~/.local/state/wezterm-claude-notify/tab-<tab_id> に退避し、
# 解除時にそこから復元する (wezterm 側の notification.lua も同じ場所を読む)。
#
# トーストは WezTerm の AUMID で出すので、Windows の
# 「設定 > システム > 通知 > WezTerm」で ON/OFF できる。
# WezTerm 自身の bell イベントは Windows の ConPTY が BEL を飲み込むため使えず、
# PowerShell から直接トーストを出している (1 回あたり約 0.3 秒)。
#
# WezTerm の外で動いている場合や wezterm/jq が無い場合は、何もせずに終了する。
#
set -u

STATUS="${1:-clear}"

# トーストを出すステータス。"waiting done" にすると応答完了ごとにも通知するが、
# 毎ターン鳴ってうるさいので既定は waiting のみ (完了はタブのマークで分かる)。
TOAST_ON="waiting"

[ -n "${WEZTERM_PANE:-}" ] || exit 0
command -v wezterm >/dev/null 2>&1 || exit 0
command -v jq      >/dev/null 2>&1 || exit 0

STATE_DIR="${HOME}/.local/state/wezterm-claude-notify"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TOAST_PS1="${SCRIPT_DIR}/wezterm-toast.ps1"

case "$STATUS" in
  waiting) MARK='[WAIT]'; TOAST_LABEL='入力待ちです' ;;
  done)    MARK='[DONE]'; TOAST_LABEL='応答が完了しました' ;;
  *)       MARK='';       TOAST_LABEL='' ;;
esac

info=$(wezterm cli list --format json 2>/dev/null) || exit 0

# 自分のペインが属するタブの tab_id / tab_title / ペインタイトル / ワークスペースを取り出す。
# Windows 版の jq は CRLF を出力するので CR を落としてから読む。
mapfile -t fields < <(
  printf '%s' "$info" \
    | jq -r --argjson p "${WEZTERM_PANE}" \
        'map(select(.pane_id == $p)) | first | select(. != null)
         | (.tab_id, .tab_title, .title, .workspace)' \
        2>/dev/null \
    | tr -d '\r'
)

TAB_ID="${fields[0]:-}"
TAB_TITLE="${fields[1]:-}"
PANE_TITLE="${fields[2]:-}"
WORKSPACE="${fields[3]:-}"

[ -n "$TAB_ID" ] || exit 0

STATE="${STATE_DIR}/tab-${TAB_ID}"

if [ -z "$MARK" ]; then
  # 解除: 退避しておいた元のタイトルに戻す (空文字なら自動タイトルに戻る)
  if [ -f "$STATE" ]; then
    wezterm cli set-tab-title --tab-id "$TAB_ID" "$(<"$STATE")" >/dev/null 2>&1 || true
    rm -f "$STATE"
  fi
  exit 0
fi

# 付与: 最初の 1 回だけ元タイトルを退避する (マークを二重に重ねないため)
if [ ! -f "$STATE" ]; then
  mkdir -p "$STATE_DIR" || exit 0
  printf '%s' "$TAB_TITLE" > "$STATE"
fi

base="$(<"$STATE")"
# タブに固有のタイトルが無い場合はペインタイトル(作業中のお題)を借りる
[ -n "$base" ] || base="$PANE_TITLE"

wezterm cli set-tab-title --tab-id "$TAB_ID" "${MARK} ${base}" >/dev/null 2>&1 || true

# デスクトップトースト
case " ${TOAST_ON} " in
  *" ${STATUS} "*)
    if [ -f "$TOAST_PS1" ] && command -v powershell.exe >/dev/null 2>&1; then
      body="$TOAST_LABEL"
      [ -n "$base" ] && body="${TOAST_LABEL}: ${base}"
      [ -n "$WORKSPACE" ] && body="${body}  (${WORKSPACE})"
      powershell.exe -NoProfile -ExecutionPolicy Bypass \
        -File "$(cygpath -w "$TOAST_PS1")" \
        -Title 'Claude Code' -Body "$body" >/dev/null 2>&1 || true
    fi
    ;;
esac

exit 0
