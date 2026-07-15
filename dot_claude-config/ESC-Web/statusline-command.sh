#!/usr/bin/env bash
# Claude Code statusline
# 表示項目: プラン識別子 | カレントディレクトリ | git ブランチ | モデル名 | コンテキスト使用量 (使用率)
#
# PLAN: "Claude Pro" または "Claude Enterprise" を設定してください
PLAN="Claude Enterprise"

# CLAUDE_CONFIG_DIR が設定されている場合、そのディレクトリ名の最後の部分を
# プランラベルに付記する (例: "Claude Enterprise(ESC-Web)")
if [ -n "${CLAUDE_CONFIG_DIR:-}" ]; then
    config_dir_name=$(basename "$CLAUDE_CONFIG_DIR")
    if [ -n "$config_dir_name" ]; then
        PLAN="${PLAN}(${config_dir_name})"
    fi
fi

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

# Claude Code バージョン (1時間キャッシュ)
_ver_cache="/tmp/.claude-code-version"
cc_version=""
if [ -f "$_ver_cache" ] && [ $(( $(date +%s) - $(date -r "$_ver_cache" +%s 2>/dev/null || echo 0) )) -lt 3600 ]; then
    cc_version=$(cat "$_ver_cache" 2>/dev/null)
else
    cc_version=$(claude --version 2>/dev/null | grep -oE '^[0-9]+\.[0-9]+\.[0-9]+' | head -1)
    [ -n "$cc_version" ] && printf '%s' "$cc_version" > "$_ver_cache"
fi

current_dir=$(printf '%s' "$input" | jq -r '.workspace.current_dir // .cwd // empty')
model_name=$(printf '%s' "$input" | jq -r '.model.display_name // "Claude"')
transcript_path=$(printf '%s' "$input" | jq -r '.transcript_path // empty')
effort_level=$(printf '%s' "$input" | jq -r '.effort.level // empty')

# effort level をモデル名に付記 (例: "Sonnet 5(medium)")
if [ -n "$effort_level" ]; then
    model_name="${model_name}(${effort_level})"
fi

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

# コスト・セッション経過時間
# NOTE: rate_limits は Claude.ai Pro/Max サブスクライバー限定で、Enterprise 等では
#       statusline の stdin に含まれないため表示できない。常に取得できる cost で代替する。
limit_seg=""
cost_usd=$(printf '%s' "$input" | jq -r '.cost.total_cost_usd // empty')
dur_ms=$(printf '%s' "$input" | jq -r '.cost.total_duration_ms // empty')
if [ -n "$cost_usd" ]; then
    cost_disp=$(printf '$%.2f' "$cost_usd" 2>/dev/null || echo "\$$cost_usd")
    dur_disp=""
    if [ -n "$dur_ms" ] && [ "$dur_ms" -gt 0 ] 2>/dev/null; then
        total_sec=$(( dur_ms / 1000 ))
        h=$(( total_sec / 3600 ))
        m=$(( (total_sec % 3600) / 60 ))
        if [ "$h" -gt 0 ]; then
            dur_disp="${h}h${m}m"
        else
            dur_disp="${m}m"
        fi
    fi
    if [ -n "$dur_disp" ]; then
        limit_seg="${C_DIM}${cost_disp} / ${dur_disp}${C_RESET}"
    else
        limit_seg="${C_DIM}${cost_disp}${C_RESET}"
    fi
fi

# 出力
sep=" ${C_DIM}|${C_RESET} "
plan_label="${PLAN}"
if [ -n "$cc_version" ]; then
    plan_label="${PLAN}(v${cc_version})"
fi

out="${C_PLAN}${plan_label}${C_RESET}"
out="${out}${sep}${C_DIR}${dir_name}${C_RESET}"
if [ -n "$branch" ]; then
    out="${out}${sep}${C_BRANCH}${branch}${C_RESET}"
fi
out="${out}${sep}${C_MODEL}${model_name}${C_RESET}"
out="${out}${sep}${C_CTX}ctx ${ctx_disp} (${context_pct}%)${C_RESET}"
if [ -n "$limit_seg" ]; then
    out="${out}${sep}${limit_seg}"
fi

printf '%s' "$out"
