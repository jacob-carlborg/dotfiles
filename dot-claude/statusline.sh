#!/bin/bash
# Claude Code status line: [model] <context bar> <pct> (<tokens>) <cwd>
#
# NOTE: the shebang resolves to /bin/bash, which is bash 3.2 on macOS — not the
# 5.x on PATH. Keep this script 3.2-compatible and test it with /bin/bash.
input=$(cat)

WIDTH=10
FILL_CHAR=▓
EMPTY_CHAR=░

# One jq call; @sh quotes each field so paths with spaces or backslashes survive.
eval "set -- $(printf '%s' "$input" | jq -r '
  [ (.model.display_name // "?"),
    (.workspace.current_dir // .cwd // ""),
    ((.context_window.used_percentage // 0) | floor),
    (.context_window as $c
     | $c.used_tokens // (($c.total_input_tokens // 0) + ($c.total_output_tokens // 0)))
  ] | @sh' 2>/dev/null)"
MODEL=${1:-?} CWD=$2 PCT=$3 TOKENS=$4

case $PCT in '' | *[!0-9]*) PCT=0 ;; esac
case $TOKENS in '' | *[!0-9]*) TOKENS=0 ;; esac

case "$CWD" in
  "$HOME") CWD="~" ;;
  "$HOME"/*) CWD="~${CWD#"$HOME"}" ;;
esac

TOKENS_FMT=$(printf "%'d" "$TOKENS" 2>/dev/null) || TOKENS_FMT=$TOKENS

# Round up, so any non-zero usage lights at least one cell.
FILLED=$(((PCT * WIDTH + 99) / 100))
[ "$FILLED" -gt "$WIDTH" ] && FILLED=$WIDTH
printf -v FILL "%${FILLED}s"
printf -v PAD "%$((WIDTH - FILLED))s"
BAR="${FILL// /$FILL_CHAR}${PAD// /$EMPTY_CHAR}"

if [ "$PCT" -ge 90 ]; then
  COLOR=$'\033[31m'       # red
elif [ "$PCT" -ge 75 ]; then
  COLOR=$'\033[38;5;208m' # orange
elif [ "$PCT" -ge 50 ]; then
  COLOR=$'\033[33m'       # yellow
else
  COLOR=$'\033[32m'       # green
fi
CYAN=$'\033[36m'
RESET=$'\033[0m'

printf '[%s] %s%s %s%% (%s tokens)%s %s%s%s\n' \
  "$MODEL" "$COLOR" "$BAR" "$PCT" "$TOKENS_FMT" "$RESET" "$CYAN" "$CWD" "$RESET"
