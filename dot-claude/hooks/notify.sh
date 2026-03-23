#!/bin/bash
#
# Notification hook for Claude Code.
# Sends macOS notifications with iTerm2 session focusing via terminal-notifier,
# falling back to osascript display notification.
#
# Usage: notify.sh <title> <message>

set -euo pipefail

TITLE="${1:?Usage: notify.sh <title> <message>}"
MESSAGE="${2:?Usage: notify.sh <title> <message>}"

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ICON_PATH="${SCRIPT_DIR}/claude_icon.png"

# Get the TTY of our ancestor process to identify the iTerm2 session.
TTY="/dev/$(ps -o tty= -p "$PPID" 2>/dev/null | tr -d ' ')" || true

# AppleScript to find and activate the iTerm2 session matching this TTY.
FOCUS_SCRIPT="
tell application \"iTerm2\"
  activate
  repeat with aWindow in windows
    repeat with aTab in tabs of aWindow
      repeat with aSession in sessions of aTab
        if tty of aSession is \"${TTY}\" then
          select aTab
          select aSession
          select aWindow
          return
        end if
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
