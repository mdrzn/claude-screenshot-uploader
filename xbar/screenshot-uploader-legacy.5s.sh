#!/bin/bash

# Claude Screenshot Uploader xbar Plugin
# Shows status and controls for the screenshot upload service
# Copy to: ~/Library/Application Support/xbar/plugins/

SERVICE_LABEL="com.claudecode.screenshot-uploader"
SCRIPT_PATH="$HOME/claude-screenshot-uploader/screenshot_uploader.sh"
STATUS_FILE="/tmp/screenshot-uploader-status"

# Check if currently uploading
if [ -f "$STATUS_FILE" ]; then
    UPLOADING_FILE=$(cat "$STATUS_FILE" | cut -d: -f2)
    STATUS="🟡"
    STATUS_TEXT="Uploading: $UPLOADING_FILE"
    ICON="📸 🟡"
# Check if service is running
elif launchctl list | grep -q "$SERVICE_LABEL"; then
    STATUS="🟢"
    STATUS_TEXT="Running"
    ICON="📸 🟢"
else
    STATUS="🔴"
    STATUS_TEXT="Stopped"
    ICON="📸 🔴"
fi

# Menu bar icon and title
echo "$ICON"
echo "---"
echo "Screenshot Uploader: $STATUS_TEXT"
echo "---"

# Service controls
if [ "$STATUS" = "🟢" ] || [ "$STATUS" = "🟡" ]; then
    echo "⏸️ Stop Service | bash='launchctl' param1='unload' param2='$HOME/Library/LaunchAgents/$SERVICE_LABEL.plist' terminal=false refresh=true"
else
    echo "▶️ Start Service | bash='launchctl' param1='load' param2='$HOME/Library/LaunchAgents/$SERVICE_LABEL.plist' terminal=false refresh=true"
fi

echo "---"

# Show recent uploads from log
echo "Recent Activity:"
if [ -f /tmp/screenshot-uploader.log ]; then
    tail -5 /tmp/screenshot-uploader.log | grep -E "(Upload successful|detected)" | while read line; do
        # Clean up the line for display
        if echo "$line" | grep -q "Upload successful"; then
            echo "  ✅ Uploaded | size=12"
        elif echo "$line" | grep -q "detected"; then
            filename=$(echo "$line" | grep -oE "SCR-[0-9]{8}-[a-z]{4}\.png" || echo "file")
            echo "  📸 $filename | size=12"
        fi
    done | head -3
else
    echo "  No activity yet | size=12"
fi

echo "---"

# Configuration and logs
if [ -f "$HOME/.claude-screenshot-uploader.conf" ]; then
    echo "⚙️ Edit Config | bash='open' param1='-e' param2='$HOME/.claude-screenshot-uploader.conf' terminal=false"
else
    echo "⚠️ Create Config | bash='cp' param1='$HOME/claude-screenshot-uploader/config.example.sh' param2='$HOME/.claude-screenshot-uploader.conf' terminal=false refresh=true"
fi
echo "📋 View Logs | bash='tail' param1='-30' param2='/tmp/screenshot-uploader.log' terminal=true"
echo "🔍 View Errors | bash='tail' param1='-30' param2='/tmp/screenshot-uploader-error.log' terminal=true"

echo "---"
echo "🔄 Refresh | refresh=true"
echo "📖 Help | href='https://github.com/yourusername/claude-screenshot-uploader'"