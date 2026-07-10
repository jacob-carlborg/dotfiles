#!/bin/sh
# Generic Claude Code WorktreeCreate hook bridging to workz.
#
# Usage (in a project's .claude/settings.json hook command):
#   ~/.claude/hooks/workz-create-worktree.sh [template-db]
#
# Claude Code sends JSON on stdin ({"name": "<worktree name>", ...}) and
# reads this script's stdout as the path of the created worktree; workz
# does the actual work (worktree, sync, ports, database) and its
# progress output is forwarded to stderr. The __workz_cd: marker workz
# prints — on creation as well as when the worktree already exists —
# carries the path.
#
# With a template-db argument the worktree gets its own database cloned
# from it (createdb -T); without one, no database is created.
set -e

template=$1
name=$(jq -r .name)

if [ -n "$template" ]; then
  out=$(workz start "$name" --isolated --create-db --from-db "$template")
else
  out=$(workz start "$name" --isolated)
fi

printf '%s\n' "$out" | grep -v '^__workz_cd:' >&2 || true
printf '%s\n' "$out" | sed -n 's/^__workz_cd://p' | tail -1
