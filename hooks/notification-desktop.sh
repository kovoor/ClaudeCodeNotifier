#!/bin/bash
# ClaudeCodeNotifier - Desktop notification hook for Claude Code
# https://github.com/kovoor/ClaudeCodeNotifier

INPUT=$(cat)

NOTIFICATION_TYPE=$(printf '%s' "$INPUT" | jq -r '.notification_type // empty')
MESSAGE=$(printf '%s' "$INPUT" | jq -r '.message // empty')

if [ -z "$NOTIFICATION_TYPE" ]; then
  exit 0
fi

TAB_LABEL=""
HOOK_DIR="$(cd "$(dirname "$0")" && pwd)"
DETECT="$HOOK_DIR/detect-ghostty-tab.sh"
if [ "$TERM_PROGRAM" = "ghostty" ] && [ -x "$DETECT" ]; then
  TAB_INDEX=$("$DETECT" "$$" 2>/dev/null)
  if [ -n "$TAB_INDEX" ]; then
    TAB_LABEL="#$TAB_INDEX"
  fi
fi

if [ -z "$TAB_LABEL" ]; then
  TAB_LABEL=$(basename "${PWD:-unknown}")
  if [ ${#TAB_LABEL} -gt 20 ]; then
    TAB_LABEL="${TAB_LABEL:0:19}…"
  fi
fi

APP="$HOME/.claude/ClaudeCodeNotifier.app"
TITLE="Claude Code"

case "$NOTIFICATION_TYPE" in
  permission_prompt)
    open -n "$APP" --args "$TITLE" "[$TAB_LABEL] Permission required" "${MESSAGE:-Claude needs your permission to continue}"
    ;;
  idle_prompt)
    open -n "$APP" --args "$TITLE" "[$TAB_LABEL] Task complete" "${MESSAGE:-Claude is waiting for your input}"
    ;;
  elicitation_dialog)
    open -n "$APP" --args "$TITLE" "[$TAB_LABEL] Input needed" "${MESSAGE:-Claude has a question for you}"
    ;;
  *)
    open -n "$APP" --args "$TITLE" "[$TAB_LABEL] Attention needed" "${MESSAGE:-Claude Code needs your attention}"
    ;;
esac
