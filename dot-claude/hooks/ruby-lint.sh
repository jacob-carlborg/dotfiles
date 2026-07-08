#!/bin/bash
# PostToolUse hook: lint Ruby files after Edit/Write and feed offenses back
# to Claude (exit 2 sends stderr to the model).

# Load rvm if present so the cd below picks up the project's
# .ruby-version/.ruby-gemset even when the hook runs outside a login shell.
[ -s "$HOME/.rvm/scripts/rvm" ] && source "$HOME/.rvm/scripts/rvm"

file=$(ruby -rjson -e 'puts JSON.parse($stdin.read).dig("tool_input", "file_path").to_s' 2>/dev/null)

case "$file" in
  *.rb | *.rake | */Rakefile | */Gemfile | *.gemspec) ;;
  *) exit 0 ;;
esac

project_dir="${CLAUDE_PROJECT_DIR:-$PWD}"
case "$file" in
  "$project_dir"/*) ;;
  *) exit 0 ;;
esac

cd "$project_dir" || exit 0

if [ -f .standard.yml ]; then
  linter=standardrb
  extra_args=""
elif [ -f .rubocop.yml ]; then
  linter=rubocop
  extra_args="--force-exclusion"
else
  exit 0
fi

# Returns 0 on clean, 2 on offenses ($output holds them), 1 on tool failure
# (bundler not set up, missing gems, etc.).
run_lint() {
  output=$("$@" $extra_args "$file" 2>&1)
  [ $? -eq 0 ] && return 0
  printf '%s\n' "$output" | grep -qE ':[0-9]+:[0-9]+:' && return 2
  return 1
}

run_lint bundle exec "$linter"
result=$?

# The project bundle may be broken or not installed; fall back to a globally
# installed linter so offenses still surface.
if [ $result -eq 1 ] && command -v "$linter" >/dev/null 2>&1; then
  run_lint "$linter"
  result=$?
fi

if [ $result -eq 2 ]; then
  {
    echo "Lint offenses in $file — fix them before finishing:"
    printf '%s\n' "$output"
  } >&2
  exit 2
fi

exit 0
