#!/bin/bash
set -e

echo "Installing ClaudeCodeNotifier..."

# XDG Base Directory paths (with defaults per spec)
XDG_DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"

INSTALL_DIR="$XDG_DATA_HOME/claude-code-notifier"
APP_DIR="$INSTALL_DIR/ClaudeCodeNotifier.app"
OC_APP_DIR="$INSTALL_DIR/OpenCodeNotifier.app"
LIB_DIR="$INSTALL_DIR/lib"
REPO="kovoor/ClaudeCodeNotifier"

# Claude Code reads its config from $CLAUDE_CONFIG_DIR (falls back to ~/.claude).
# The notification hook is Claude-specific so it lives alongside Claude's other
# hooks; the shared tab-detection helper lives under the data dir because the
# OpenCode plugin uses it too.
CLAUDE_SETTINGS_DIR="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
SETTINGS_FILE="$CLAUDE_SETTINGS_DIR/settings.json"
CLAUDE_HOOK_DIR="$CLAUDE_SETTINGS_DIR/hooks"

# OpenCode bits are only installed if the opencode CLI is on PATH.
if command -v opencode >/dev/null 2>&1; then
  HAVE_OPENCODE=1
else
  HAVE_OPENCODE=0
fi

# Download pre-built app
echo "Downloading ClaudeCodeNotifier.app..."
TMPDIR=$(mktemp -d)
curl -fsSL "https://github.com/$REPO/releases/latest/download/ClaudeCodeNotifier-macos-universal.zip" -o "$TMPDIR/app.zip"
unzip -qo "$TMPDIR/app.zip" -d "$TMPDIR"

# Install app
mkdir -p "$INSTALL_DIR"
rm -rf "$APP_DIR"
mv "$TMPDIR/ClaudeCodeNotifier.app" "$APP_DIR"
rm -rf "$TMPDIR"

# Register with macOS
/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f "$APP_DIR"

if [ "$HAVE_OPENCODE" = "1" ]; then
  # Build OpenCodeNotifier.app by cloning the Claude bundle with OpenCode branding.
  echo "Building OpenCodeNotifier.app..."
  rm -rf "$OC_APP_DIR"
  mkdir -p "$OC_APP_DIR/Contents/MacOS"
  mkdir -p "$OC_APP_DIR/Contents/Resources"
  cp "$APP_DIR/Contents/MacOS/ClaudeNotifier" "$OC_APP_DIR/Contents/MacOS/ClaudeNotifier"
  curl -fsSL "https://raw.githubusercontent.com/$REPO/main/src/Info-OpenCode.plist" -o "$OC_APP_DIR/Contents/Info.plist"
  curl -fsSL "https://raw.githubusercontent.com/$REPO/main/assets/opencode-icon.icns" -o "$OC_APP_DIR/Contents/Resources/AppIcon.icns"
  codesign --force --sign - "$OC_APP_DIR" 2>/dev/null || true
  /System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f "$OC_APP_DIR"
else
  echo "Skipping OpenCode bundle: 'opencode' not found on PATH."
fi

# Install shared tab-detection helper next to the apps.
echo "Installing shared lib..."
mkdir -p "$LIB_DIR"
curl -fsSL "https://raw.githubusercontent.com/$REPO/main/hooks/detect-ghostty-tab.sh" -o "$LIB_DIR/detect-ghostty-tab.sh"
chmod +x "$LIB_DIR/detect-ghostty-tab.sh"

# Install the Claude Code hook alongside Claude's other hooks.
echo "Installing Claude Code notification hook..."
mkdir -p "$CLAUDE_HOOK_DIR"
curl -fsSL "https://raw.githubusercontent.com/$REPO/main/hooks/notification-desktop.sh" -o "$CLAUDE_HOOK_DIR/notification-desktop.sh"
chmod +x "$CLAUDE_HOOK_DIR/notification-desktop.sh"

if [ "$HAVE_OPENCODE" = "1" ]; then
  # Download and install OpenCode plugin
  echo "Installing OpenCode notification plugin..."
  OPENCODE_PLUGIN_DIR="$XDG_CONFIG_HOME/opencode/plugins"
  mkdir -p "$OPENCODE_PLUGIN_DIR"
  curl -fsSL "https://raw.githubusercontent.com/$REPO/main/hooks/opencode-notifier.js" -o "$OPENCODE_PLUGIN_DIR/opencode-notifier.js"
fi

# Configure Claude Code settings.json
HOOK_CMD="$CLAUDE_HOOK_DIR/notification-desktop.sh"
HOOK_CMD_DISPLAY="${HOOK_CMD/#$HOME\//~/}"
if [ -f "$SETTINGS_FILE" ]; then
  if grep -q "notification-desktop.sh" "$SETTINGS_FILE" 2>/dev/null; then
    echo "Hook already configured in settings.json"
  else
    echo ""
    echo "Add this to your $SETTINGS_FILE:"
    echo ""
    cat <<CONF
  "hooks": {
    "Notification": [
      {
        "matcher": "",
        "hooks": [
          {
            "type": "command",
            "command": "$HOOK_CMD_DISPLAY",
            "timeout": 10
          }
        ]
      }
    ]
  }
CONF
  fi
else
  mkdir -p "$CLAUDE_SETTINGS_DIR"
  cat > "$SETTINGS_FILE" <<EOF
{
  "hooks": {
    "Notification": [
      {
        "matcher": "",
        "hooks": [
          {
            "type": "command",
            "command": "$HOOK_CMD_DISPLAY",
            "timeout": 10
          }
        ]
      }
    ]
  }
}
EOF
  echo "Created $SETTINGS_FILE"
fi

# Request notification permission
echo "Requesting notification permission..."
open "$APP_DIR" --args "Claude Code" "Setup complete" "ClaudeCodeNotifier is ready"
if [ "$HAVE_OPENCODE" = "1" ]; then
  open "$OC_APP_DIR" --args "OpenCode" "Setup complete" "OpenCodeNotifier is ready"
fi

echo ""
echo "Installation complete!"
echo ""
echo "  Claude app:      $APP_DIR"
if [ "$HAVE_OPENCODE" = "1" ]; then
  echo "  OpenCode app:    $OC_APP_DIR"
fi
echo "  Claude hook:     $CLAUDE_HOOK_DIR/notification-desktop.sh"
echo "  Shared lib:      $LIB_DIR/detect-ghostty-tab.sh"
if [ "$HAVE_OPENCODE" = "1" ]; then
  echo "  OpenCode plugin: $OPENCODE_PLUGIN_DIR/opencode-notifier.js"
fi
echo "  Claude settings: $SETTINGS_FILE"
echo ""
echo "Make sure to:"
if [ "$HAVE_OPENCODE" = "1" ]; then
  echo "  1. Allow notifications for 'Claude Code Notifier' and 'OpenCode Notifier' in System Settings > Notifications"
else
  echo "  1. Allow notifications for 'Claude Code Notifier' in System Settings > Notifications"
fi
echo "  2. Grant Ghostty accessibility access for tab detection (optional)"
if [ "$HAVE_OPENCODE" = "1" ]; then
  echo "  3. Restart Claude Code and OpenCode for notifications to take effect"
else
  echo "  3. Restart Claude Code for notifications to take effect"
  echo ""
  echo "Note: 'opencode' was not found on PATH. Re-run this installer after installing OpenCode to add support."
fi
