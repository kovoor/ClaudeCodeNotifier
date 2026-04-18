#!/bin/bash
# Detect which Ghostty tab the given PID is running in.
# Prints the tab number to stdout (e.g. "4") or nothing if detection fails.
#
# Usage: detect-ghostty-tab.sh [START_PID]
# START_PID defaults to the parent of this script.

START_PID="${1:-$PPID}"

# Walk up the process tree until we find a PID attached to a TTY.
find_tty() {
  local pid="$1"
  local tty
  for _ in 1 2 3 4 5 6 7 8; do
    [ -z "$pid" ] || [ "$pid" = "0" ] || [ "$pid" = "1" ] && break
    tty=$(ps -o tty= -p "$pid" 2>/dev/null | tr -d ' ')
    if [ -n "$tty" ] && [ "$tty" != "??" ]; then
      printf '%s\n' "$tty"
      return 0
    fi
    pid=$(ps -o ppid= -p "$pid" 2>/dev/null | tr -d ' ')
  done
  return 1
}

TTY=$(find_tty "$START_PID") || exit 0
[ -n "$TTY" ] || exit 0

MARKER="__CCN_TAB_MARKER_$$_$(date +%s%N)__"
printf '\033]0;%s\007' "$MARKER" > "/dev/$TTY" 2>/dev/null || exit 0
sleep 0.05

TAB_INDEX=$(osascript -e "
  tell application \"System Events\"
    tell process \"Ghostty\"
      tell window 1
        tell tab group \"tab bar\"
          set tabButtons to every radio button
          set idx to 1
          repeat with t in tabButtons
            if name of t contains \"$MARKER\" then
              return idx as text
            end if
            set idx to idx + 1
          end repeat
          return \"\"
        end tell
      end tell
    end tell
  end tell
" 2>/dev/null)

# Restore an empty title (Ghostty falls back to shell-managed title).
printf '\033]0;\007' > "/dev/$TTY" 2>/dev/null || true

if [ -n "$TAB_INDEX" ]; then
  printf '%s\n' "$TAB_INDEX"
fi
