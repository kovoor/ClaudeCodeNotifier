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

# Build OpenCodeNotifier.app by cloning the Claude bundle with OpenCode branding.
OPENCODE_ICNS="/Applications/OpenCode.app/Contents/Resources/icon.icns"
OC_APP_DIR="$INSTALL_DIR/OpenCodeNotifier.app"
if [ -f "$OPENCODE_ICNS" ]; then
  echo "Building OpenCodeNotifier.app..."
  rm -rf "$OC_APP_DIR"
  mkdir -p "$OC_APP_DIR/Contents/MacOS"
  mkdir -p "$OC_APP_DIR/Contents/Resources"
  cp "$APP_DIR/Contents/MacOS/ClaudeNotifier" "$OC_APP_DIR/Contents/MacOS/ClaudeNotifier"
  curl -fsSL "https://raw.githubusercontent.com/$REPO/main/src/Info-OpenCode.plist" -o "$OC_APP_DIR/Contents/Info.plist"
  cp "$OPENCODE_ICNS" "$OC_APP_DIR/Contents/Resources/AppIcon.icns"
  codesign --force --sign - "$OC_APP_DIR" 2>/dev/null || true
  /System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f "$OC_APP_DIR"
else
  echo "Note: /Applications/OpenCode.app not found — skipping OpenCodeNotifier.app."
  echo "      Install OpenCode and rerun this script to enable OpenCode notifications."
fi

# Download and install Claude Code hook + shared tab-detection helper
echo "Installing Claude Code notification hook..."
mkdir -p "$INSTALL_DIR/hooks"
curl -fsSL "https://raw.githubusercontent.com/$REPO/main/hooks/notification-desktop.sh" -o "$INSTALL_DIR/hooks/notification-desktop.sh"
curl -fsSL "https://raw.githubusercontent.com/$REPO/main/hooks/detect-ghostty-tab.sh" -o "$INSTALL_DIR/hooks/detect-ghostty-tab.sh"
chmod +x "$INSTALL_DIR/hooks/notification-desktop.sh" "$INSTALL_DIR/hooks/detect-ghostty-tab.sh"

# Download and install OpenCode plugin
echo "Installing OpenCode notification plugin..."
OPENCODE_PLUGIN_DIR="$HOME/.config/opencode/plugins"
mkdir -p "$OPENCODE_PLUGIN_DIR"
curl -fsSL "https://raw.githubusercontent.com/$REPO/main/hooks/opencode-notifier.js" -o "$OPENCODE_PLUGIN_DIR/opencode-notifier.js"

# Configure Claude Code settings.json
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
echo "  2. Grant Ghostty accessibility access for tab detection (optional)"
echo "  3. Restart Claude Code and OpenCode for notifications to take effect"
