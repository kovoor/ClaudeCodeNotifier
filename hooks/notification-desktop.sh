#!/bin/bash
# ClaudeCodeNotifier - Desktop notification hook for Claude Code
# https://github.com/kovoor/ClaudeCodeNotifier

INPUT=$(cat)

NOTIFICATION_TYPE=$(printf '%s' "$INPUT" | jq -r '.notification_type // empty')
MESSAGE=$(printf '%s' "$INPUT" | jq -r '.message // empty')

if [ -z "$NOTIFICATION_TYPE" ]; then
  exit 0
fi

# Ghostty tab detection via TTY marker
TAB_LABEL=""
if [ "$TERM_PROGRAM" = "ghostty" ]; then
  OUR_TTY=$(ps -o tty= -p $(ps -o ppid= -p $(ps -o ppid= -p $$ | tr -d ' ') | tr -d ' ') 2>/dev/null | tr -d ' ')
  if [ -n "$OUR_TTY" ] && [ "$OUR_TTY" != "??" ]; then
    MARKER="__CLAUDE_HOOK_$$__"
    printf '\033]0;%s\007' "$MARKER" > /dev/$OUR_TTY 2>/dev/null
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
    printf '\033]0;\007' > /dev/$OUR_TTY 2>/dev/null
    if [ -n "$TAB_INDEX" ]; then
      TAB_LABEL="Tab $TAB_INDEX"
    fi
  fi
fi

if [ -z "$TAB_LABEL" ]; then
  TAB_LABEL=$(basename "${PWD:-unknown}")
fi

APP="$HOME/.claude/ClaudeCodeNotifier.app"

case "$NOTIFICATION_TYPE" in
  permission_prompt)
    open -n "$APP" --args "[$TAB_LABEL] Permission required" "${MESSAGE:-Claude needs your permission to continue}"
    ;;
  idle_prompt)
    open -n "$APP" --args "[$TAB_LABEL] Task complete" "${MESSAGE:-Claude is waiting for your input}"
    ;;
  elicitation_dialog)
    open -n "$APP" --args "[$TAB_LABEL] Input needed" "${MESSAGE:-Claude has a question for you}"
    ;;
  *)
    open -n "$APP" --args "[$TAB_LABEL] Attention needed" "${MESSAGE:-Claude Code needs your attention}"
    ;;
esac
