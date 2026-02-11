#!/bin/bash
set -e

echo "Installing ClaudeCodeNotifier..."

INSTALL_DIR="$HOME/.claude"
APP_DIR="$INSTALL_DIR/ClaudeCodeNotifier.app"
REPO="kovoor/ClaudeCodeNotifier"

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

# Download and install hook
echo "Installing notification hook..."
mkdir -p "$INSTALL_DIR/hooks"
curl -fsSL "https://raw.githubusercontent.com/$REPO/main/hooks/notification-desktop.sh" -o "$INSTALL_DIR/hooks/notification-desktop.sh"
chmod +x "$INSTALL_DIR/hooks/notification-desktop.sh"

# Configure settings.json
SETTINGS_FILE="$INSTALL_DIR/settings.json"
if [ -f "$SETTINGS_FILE" ]; then
  if grep -q "notification-desktop.sh" "$SETTINGS_FILE" 2>/dev/null; then
    echo "Hook already configured in settings.json"
  else
    echo ""
    echo "Add this to your $SETTINGS_FILE:"
    echo ""
    cat << 'CONF'
  "hooks": {
    "Notification": [
      {
        "matcher": "",
        "hooks": [
          {
            "type": "command",
            "command": "~/.claude/hooks/notification-desktop.sh",
            "timeout": 10
          }
        ]
      }
    ]
  }
CONF
  fi
else
  cat > "$SETTINGS_FILE" << 'EOF'
{
  "hooks": {
    "Notification": [
      {
        "matcher": "",
        "hooks": [
          {
            "type": "command",
            "command": "~/.claude/hooks/notification-desktop.sh",
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
open "$APP_DIR" --args "Setup complete" "ClaudeCodeNotifier is ready"

echo ""
echo "Installation complete!"
echo ""
echo "Make sure to:"
echo "  1. Allow notifications for 'Claude Code Notifier' in System Settings > Notifications"
echo "  2. Grant Ghostty accessibility access for tab detection (optional)"
echo "  3. Restart Claude Code for hooks to take effect"
