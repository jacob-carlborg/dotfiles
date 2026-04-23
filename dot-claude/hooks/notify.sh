#!/bin/bash
#
# Notification hook for Claude Code.
#
# Non-tmux: terminal-notifier with a custom icon, plus AppleScript focusing
# the iTerm2 session whose tty matches our ancestor process.
#
# tmux + iTerm2 integration: tmux-backed iTerm2 sessions expose no stable
# identifier via AppleScript (no real tty, no tmuxPane variable, and
# ITERM_SESSION_ID is inherited/stale). Use iTerm2's OSC 9 notification
# through tmux passthrough instead — iTerm2 attributes the notification to
# the originating session and handles click-to-focus natively. Requires
# `set -g allow-passthrough on` in tmux.conf (tmux >= 3.3).
#
# Usage: notify.sh <title> <message>

set -euo pipefail

TITLE="${1:?Usage: notify.sh <title> <message>}"
MESSAGE="${2:?Usage: notify.sh <title> <message>}"

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ICON_PATH="${SCRIPT_DIR}/claude_icon.png"

if [ -n "${TMUX:-}" ] && [ "${LC_TERMINAL:-}" = "iTerm2" ]; then
  # OSC 9 (notification) wrapped in tmux's DCS passthrough: ESC P tmux ; ESC <osc> ESC \
  printf '\ePtmux;\e\e]9;%s: %s\a\e\\' "$TITLE" "$MESSAGE" > /dev/tty 2>/dev/null || true
  exit 0
fi

TTY="/dev/$(ps -o tty= -p "$PPID" 2>/dev/null | tr -d ' ')" || true

FOCUS_SCRIPT="
tell application \"iTerm2\"
  activate
  repeat with aWindow in windows
    repeat with aTab in tabs of aWindow
      repeat with aSession in sessions of aTab
        try
          if tty of aSession is \"${TTY}\" then
            select aTab
            select aSession
            select aWindow
            return
          end if
        end try
      end repeat
    end repeat
  end repeat
end tell"

if command -v terminal-notifier >/dev/null 2>&1; then
  EXECUTE_CMD="osascript -e '${FOCUS_SCRIPT}'"
  APP_ICON="file://${ICON_PATH}"
  terminal-notifier \
    -title "$TITLE" \
    -message "$MESSAGE" \
    -appIcon "$APP_ICON" \
    -execute "$EXECUTE_CMD"
else
  osascript -e "display notification \"${MESSAGE}\" with title \"${TITLE}\""
fi
