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

# Build OpenCodeNotifier.app — separate bundle with OpenCode icon so macOS
# renders the OpenCode logo on the notification banner.
OPENCODE_ICNS="/Applications/OpenCode.app/Contents/Resources/icon.icns"
OC_APP_DIR="$INSTALL_DIR/OpenCodeNotifier.app"
if [ -f "$OPENCODE_ICNS" ]; then
  echo "Building OpenCodeNotifier.app..."
  rm -rf "$OC_APP_DIR"
  mkdir -p "$OC_APP_DIR/Contents/MacOS"
  mkdir -p "$OC_APP_DIR/Contents/Resources"
  # Share the compiled binary across bundles.
  cp "$APP_DIR/Contents/MacOS/ClaudeNotifier" "$OC_APP_DIR/Contents/MacOS/ClaudeNotifier"
  cp "$SCRIPT_DIR/src/Info-OpenCode.plist" "$OC_APP_DIR/Contents/Info.plist"
  cp "$OPENCODE_ICNS" "$OC_APP_DIR/Contents/Resources/AppIcon.icns"
  codesign --force --sign - "$OC_APP_DIR"
  /System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f "$OC_APP_DIR"
else
  echo "Note: /Applications/OpenCode.app not found — skipping OpenCodeNotifier.app build."
  echo "      Install OpenCode and rerun this script to enable OpenCode notifications."
fi

# Install Claude Code hook + shared tab-detection helper
mkdir -p "$INSTALL_DIR/hooks"
cp "$SCRIPT_DIR/hooks/notification-desktop.sh" "$INSTALL_DIR/hooks/notification-desktop.sh"
cp "$SCRIPT_DIR/hooks/detect-ghostty-tab.sh" "$INSTALL_DIR/hooks/detect-ghostty-tab.sh"
chmod +x "$INSTALL_DIR/hooks/notification-desktop.sh" "$INSTALL_DIR/hooks/detect-ghostty-tab.sh"

# Install OpenCode plugin (auto-loaded from ~/.config/opencode/plugins/)
OPENCODE_PLUGIN_DIR="$HOME/.config/opencode/plugins"
mkdir -p "$OPENCODE_PLUGIN_DIR"
cp "$SCRIPT_DIR/hooks/opencode-notifier.js" "$OPENCODE_PLUGIN_DIR/opencode-notifier.js"
echo "Installed OpenCode plugin to $OPENCODE_PLUGIN_DIR/opencode-notifier.js"

# Update Claude Code settings.json
SETTINGS_FILE="$INSTALL_DIR/settings.json"
if [ -f "$SETTINGS_FILE" ]; then
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
open "$APP_DIR" --args "Claude Code" "Setup complete" "ClaudeCodeNotifier is ready"
if [ -d "$OC_APP_DIR" ]; then
  open "$OC_APP_DIR" --args "OpenCode" "Setup complete" "OpenCodeNotifier is ready"
fi

echo ""
echo "Installation complete!"
echo ""
echo "  Claude app:      $APP_DIR"
if [ -d "$OC_APP_DIR" ]; then
  echo "  OpenCode app:    $OC_APP_DIR"
fi
echo "  Claude hook:     $INSTALL_DIR/hooks/notification-desktop.sh"
echo "  OpenCode plugin: $OPENCODE_PLUGIN_DIR/opencode-notifier.js"
echo ""
echo "Make sure to:"
echo "  1. Allow notifications for 'Claude Code Notifier' and 'OpenCode Notifier' in System Settings > Notifications"
echo "  2. Grant Ghostty accessibility access in System Settings > Privacy & Security > Accessibility (for tab detection)"
echo "  3. Restart Claude Code and OpenCode for notifications to take effect"
