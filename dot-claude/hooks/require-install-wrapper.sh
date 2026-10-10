#!/bin/bash
# PreToolUse hook: block "<tool> install" (and bare "<tool>", which also
# installs) in Bash commands and point Claude at the wrapper that handles
# authentication (exit 2 sends stderr to the model).
#
# Only commands in command position are matched (start of line or after
# ; & | ( {), so mentions such as `which yarn` or `ls vendor/bundle` pass.
# Backticks are not treated as command boundaries, so Markdown code spans in
# commit messages pass too; use $(...) for command substitution.
#
# Usage: require-install-wrapper.sh <tool> <wrapper> [<tool> <wrapper>...]
#   e.g. require-install-wrapper.sh bundle bundle-install yarn yarn-install

command=$(jq -r '.tool_input.command // empty' 2>/dev/null)

separator='[;&|)}]'
terminator="(${separator}|$)"
start='(^|[;&|({])[[:space:]]*'
prefix='(([A-Za-z_][A-Za-z0-9_]*=[^[:space:]]*|command|env|exec|sudo|time)[[:space:]]+)*'
path='([^[:space:];&|(){}`]*/)?'
options='([[:space:]]+(-[^[:space:];&|)}`]*|_[^[:space:];&|)}`]*_))*'
install="${options}[[:space:]]+(install|i)([[:space:]]|${terminator})"
bare="[[:space:]]*${terminator}"

while [ $# -ge 2 ]; do
  tool="$1"
  wrapper="$2"
  shift 2

  if printf '%s\n' "$command" | grep -qE "${start}${prefix}${path}${tool}(${install}|${bare})"; then
    echo "Don't run \`$tool install\`. Run \`$wrapper\` instead, which handles authentication." >&2
    exit 2
  fi
done

exit 0
