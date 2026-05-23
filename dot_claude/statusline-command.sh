#!/usr/bin/env bash
# Claude Code statusline
# 表示項目: プラン識別子 | カレントディレクトリ | git ブランチ | モデル名 | コンテキスト使用量 (使用率)
#
# PLAN: "Claude Pro" または "Claude Enterprise" を設定してください
PLAN="Claude Pro"

set -u

ESC=$'\033'
C_RESET="${ESC}[0m"
C_DIM="${ESC}[2m"
C_DIR="${ESC}[36m"     # cyan
C_BRANCH="${ESC}[32m"  # green
C_MODEL="${ESC}[33m"   # yellow
C_OK="${ESC}[32m"
C_WARN="${ESC}[33m"
C_DANGER="${ESC}[31m"
C_PLAN="${ESC}[35m"    # magenta

input=$(cat)

current_dir=$(printf '%s' "$input" | jq -r '.workspace.current_dir // .cwd // empty')
model_name=$(printf '%s' "$input" | jq -r '.model.display_name // "Claude"')
transcript_path=$(printf '%s' "$input" | jq -r '.transcript_path // empty')

# カレントディレクトリ (ベース名のみ)
if [ -n "$current_dir" ]; then
    dir_name=$(basename "$current_dir")
else
    dir_name="(unknown)"
fi

# git ブランチ
branch=""
if [ -n "$current_dir" ]; then
    branch=$(git -C "$current_dir" symbolic-ref --short HEAD 2>/dev/null) || \
    branch=$(git -C "$current_dir" describe --tags --exact-match 2>/dev/null) || \
    branch=$(git -C "$current_dir" rev-parse --short HEAD 2>/dev/null) || \
    branch=""
fi

# コンテキスト上限 (モデル名から判定)
context_limit=200000
case "$model_name" in
    *1M*|*1m*) context_limit=1000000 ;;
esac

# コンテキスト使用量: transcript から計算、なければ context_window フィールドを利用
context_used=0
context_pct=0
if [ -n "$transcript_path" ] && [ -f "$transcript_path" ]; then
    last_usage=$(grep '"usage"' "$transcript_path" 2>/dev/null | tail -n 1)
    if [ -n "$last_usage" ]; then
        tokens=$(printf '%s' "$last_usage" | jq -r '
            ((.message.usage.input_tokens // 0) +
             (.message.usage.cache_read_input_tokens // 0) +
             (.message.usage.cache_creation_input_tokens // 0))
        ' 2>/dev/null)
        if [ -n "$tokens" ] && [ "$tokens" -gt 0 ] 2>/dev/null; then
            context_used=$tokens
            context_pct=$(( context_used * 100 / context_limit ))
        fi
    fi
fi

# transcript から取れなかった場合は context_window フィールドを利用
if [ "$context_used" -eq 0 ]; then
    cw_used=$(printf '%s' "$input" | jq -r '.context_window.total_input_tokens // empty')
    cw_pct=$(printf '%s' "$input" | jq -r '.context_window.used_percentage // empty')
    cw_size=$(printf '%s' "$input" | jq -r '.context_window.context_window_size // empty')
    if [ -n "$cw_used" ] && [ "$cw_used" -gt 0 ] 2>/dev/null; then
        context_used=$cw_used
        if [ -n "$cw_size" ] && [ "$cw_size" -gt 0 ] 2>/dev/null; then
            context_limit=$cw_size
        fi
        context_pct=$(( context_used * 100 / context_limit ))
    elif [ -n "$cw_pct" ]; then
        context_pct=$(printf '%.0f' "$cw_pct" 2>/dev/null || echo 0)
    fi
fi

# 使用量フォーマット (k 単位、小数1桁)
if [ "$context_used" -ge 1000 ]; then
    whole=$(( context_used / 1000 ))
    decimal=$(( (context_used % 1000) / 100 ))
    ctx_disp="${whole}.${decimal}k"
else
    ctx_disp="${context_used}"
fi

# 使用率に応じた色
if [ "$context_pct" -ge 80 ]; then
    C_CTX="$C_DANGER"
elif [ "$context_pct" -ge 50 ]; then
    C_CTX="$C_WARN"
else
    C_CTX="$C_OK"
fi

# 出力
sep=" ${C_DIM}|${C_RESET} "
out="${C_PLAN}${PLAN}${C_RESET}"
out="${out}${sep}${C_DIR}${dir_name}${C_RESET}"
if [ -n "$branch" ]; then
    out="${out}${sep}${C_BRANCH}${branch}${C_RESET}"
fi
out="${out}${sep}${C_MODEL}${model_name}${C_RESET}"
out="${out}${sep}${C_CTX}ctx ${ctx_disp} (${context_pct}%)${C_RESET}"

printf '%s' "$out"
