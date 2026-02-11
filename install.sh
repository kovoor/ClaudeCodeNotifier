#!/bin/bash
set -e

echo "Installing ClaudeCodeNotifier..."

INSTALL_DIR="$HOME/.claude"
APP_NAME="ClaudeCodeNotifier.app"
APP_DIR="$INSTALL_DIR/$APP_NAME"

# Build the app
echo "Building ClaudeCodeNotifier.app..."
mkdir -p "$APP_DIR/Contents/MacOS"
mkdir -p "$APP_DIR/Contents/Resources"

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

swiftc "$SCRIPT_DIR/src/main.swift" \
  -o "$APP_DIR/Contents/MacOS/ClaudeNotifier" \
  -framework Cocoa \
  -framework UserNotifications

cp "$SCRIPT_DIR/src/Info.plist" "$APP_DIR/Contents/"
cp "$SCRIPT_DIR/assets/claude-icon.icns" "$APP_DIR/Contents/Resources/AppIcon.icns"

# Ad-hoc sign
codesign --force --sign - "$APP_DIR"

# Register with macOS
/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f "$APP_DIR"

# Install hook
mkdir -p "$INSTALL_DIR/hooks"
cp "$SCRIPT_DIR/hooks/notification-desktop.sh" "$INSTALL_DIR/hooks/notification-desktop.sh"
chmod +x "$INSTALL_DIR/hooks/notification-desktop.sh"

# Update settings.json
SETTINGS_FILE="$INSTALL_DIR/settings.json"
if [ -f "$SETTINGS_FILE" ]; then
  # Check if hooks already configured
  if grep -q "notification-desktop.sh" "$SETTINGS_FILE" 2>/dev/null; then
    echo "Hook already configured in settings.json"
  else
    echo ""
    echo "Add this to your $SETTINGS_FILE under the top-level object:"
    echo ""
    echo '  "hooks": {'
    echo '    "Notification": ['
    echo '      {'
    echo '        "matcher": "",'
    echo '        "hooks": ['
    echo '          {'
    echo '            "type": "command",'
    echo '            "command": "~/.claude/hooks/notification-desktop.sh",'
    echo '            "timeout": 10'
    echo '          }'
    echo '        ]'
    echo '      }'
    echo '    ]'
    echo '  }'
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
  echo "Created $SETTINGS_FILE with hook configuration"
fi

# Trigger first run to request notification permission
echo ""
echo "Requesting notification permission..."
open "$APP_DIR" --args "Setup complete" "ClaudeCodeNotifier is ready"

echo ""
echo "Installation complete!"
echo ""
echo "  App:  $APP_DIR"
echo "  Hook: $INSTALL_DIR/hooks/notification-desktop.sh"
echo ""
echo "Make sure to:"
echo "  1. Allow notifications for 'Claude Code Notifier' in System Settings > Notifications"
echo "  2. Grant Ghostty accessibility access in System Settings > Privacy & Security > Accessibility (for tab detection)"
echo "  3. Restart Claude Code for hooks to take effect"
