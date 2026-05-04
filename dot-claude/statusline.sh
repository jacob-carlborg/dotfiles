#!/bin/bash
input=$(cat)
MODEL=$(echo "$input" | jq -r '.model.display_name')
PCT=$(echo "$input" | jq -r '.context_window.used_percentage // 0' | cut -d. -f1)
TOKENS=$(echo "$input" | jq -r '
  [
    .context_window.used_tokens // empty,
    ((.context_window.total_input_tokens // 0) + (.context_window.total_output_tokens // 0)),
    0
  ] | map(select(. != null)) | .[0]
')
TOKENS_FMT=$(printf "%'d" "$TOKENS" 2>/dev/null || echo "$TOKENS")

FILLED=$((PCT / 10))
EMPTY=$((10 - FILLED))
printf -v FILL "%${FILLED}s"
printf -v PAD "%${EMPTY}s"
BAR="${FILL// /▓}${PAD// /░}"

if [ "$PCT" -ge 80 ]; then
  COLOR="\033[31m" # red
elif [ "$PCT" -ge 50 ]; then
  COLOR="\033[33m" # yellow
else
  COLOR="\033[32m" # green
fi
RESET="\033[0m"

echo -e "[$MODEL] ${COLOR}${BAR} ${PCT}% (${TOKENS_FMT} tokens)${RESET}"
