#!/bin/bash

# Claude Screenshot Uploader xbar Plugin v3 - Manual Upload Mode
# Shows servers and allows manual upload of latest screenshot
# Copy to: ~/Library/Application Support/xbar/plugins/

SCRIPT_DIR="$HOME/claude-screenshot-uploader"
CONFIG_FILE="$HOME/.claude-screenshot-uploader/config.json"
STATUS_FILE="/tmp/screenshot-uploader-status"
SCREENSHOTS_DIR="$HOME/Screenshots"

# Check if config exists
if [ ! -f "$CONFIG_FILE" ]; then
    echo "📸 ⚠️"
    echo "---"
    echo "⚠️ Not Configured"
    echo "---"
    echo "➕ Add First Server... | shell='$SCRIPT_DIR/helpers/add-server.sh' terminal=false refresh=true"
    echo "---"
    echo "📖 Help | href='https://github.com/mdrzn/claude-screenshot-uploader'"
    exit 0
fi

# Get active server and list of all servers
SERVERS_INFO=$(python3 << 'EOF'
import json
import sys
import os

config_file = os.path.expanduser("~/.claude-screenshot-uploader/config.json")

try:
    with open(config_file, 'r') as f:
        config = json.load(f)

    active = config.get('active', '')
    servers = config.get('servers', {})

    # Print active server first
    if active and active in servers:
        print(f"ACTIVE:{active}:{servers[active].get('name', active)}:{servers[active]['host']}")
    else:
        print("ACTIVE:none:No Active Server:none")

    # Print all servers
    for key, server in servers.items():
        print(f"SERVER:{key}:{server.get('name', key)}:{server['host']}")

except Exception as e:
    print(f"ERROR:config:Error reading config:{e}")
    sys.exit(1)
EOF
)

# Parse active server info
ACTIVE_LINE=$(echo "$SERVERS_INFO" | grep "^ACTIVE:")
IFS=':' read -r _ ACTIVE_KEY ACTIVE_NAME ACTIVE_HOST <<< "$ACTIVE_LINE"

# Check if currently uploading
if [ -f "$STATUS_FILE" ]; then
    IFS=':' read -r _ UPLOADING_FILE UPLOADING_SERVER <<< $(cat "$STATUS_FILE")
    ICON="📸 🔵"
    STATUS_TEXT="Uploading to $UPLOADING_SERVER..."
# Default idle state
else
    if [ "$ACTIVE_KEY" != "none" ]; then
        # Show abbreviated server name in menu bar
        if [ ${#ACTIVE_HOST} -gt 15 ]; then
            SHORT_HOST=$(echo "$ACTIVE_HOST" | cut -c1-12)...
        else
            SHORT_HOST="$ACTIVE_HOST"
        fi
        ICON="📸 → $SHORT_HOST"
        STATUS_TEXT="Ready to upload"
    else
        ICON="📸"
        STATUS_TEXT="No server selected"
    fi
fi

# Find latest screenshot info
LATEST_SCREENSHOT=$(find "$SCREENSHOTS_DIR" -maxdepth 1 -type f \( -name "SCR-*.png" -o -name "SCR-*.jpeg" -o -name "Screenshot *.png" -o -name "Screenshot *.jpg" -o -name "Screenshot *.jpeg" \) -print0 2>/dev/null | xargs -0 ls -t 2>/dev/null | head -n 1)

if [ -n "$LATEST_SCREENSHOT" ]; then
    LATEST_FILENAME=$(basename "$LATEST_SCREENSHOT")
    # Get file modification time in a readable format
    LATEST_TIME=$(stat -f "%Sm" -t "%b %d, %H:%M" "$LATEST_SCREENSHOT" 2>/dev/null)
else
    LATEST_FILENAME="No screenshots found"
    LATEST_TIME=""
fi

# Menu bar icon and title
echo "$ICON"
echo "---"

# Latest screenshot info
if [ -n "$LATEST_SCREENSHOT" ]; then
    echo "📸 Latest Screenshot:"
    echo "--$LATEST_FILENAME | size=11"
    if [ -n "$LATEST_TIME" ]; then
        echo "--$LATEST_TIME | size=10 color=gray"
    fi
else
    echo "📸 No screenshots found | color=gray"
fi

echo "---"

# Upload actions
if [ -n "$LATEST_SCREENSHOT" ]; then
    if [ "$ACTIVE_KEY" != "none" ]; then
        echo "📤 Upload to $ACTIVE_NAME | shell='$SCRIPT_DIR/helpers/upload-latest.sh' terminal=false refresh=true"
    else
        echo "📤 Upload Latest Screenshot | disabled=true"
        echo "--⚠️ Select a server first | size=11 color=gray"
    fi

    # Upload to specific server submenu
    SERVER_COUNT=$(echo "$SERVERS_INFO" | grep "^SERVER:" | wc -l | tr -d ' ')

    if [ $SERVER_COUNT -gt 1 ]; then
        echo "📤 Upload to..."

        echo "$SERVERS_INFO" | grep "^SERVER:" | while IFS=':' read -r _ KEY NAME HOST; do
            if [ "$KEY" = "$ACTIVE_KEY" ]; then
                echo "--✓ $NAME | shell='$SCRIPT_DIR/helpers/upload-latest.sh' param1='$KEY' terminal=false refresh=true"
            else
                echo "--$NAME | shell='$SCRIPT_DIR/helpers/upload-latest.sh' param1='$KEY' terminal=false refresh=true"
            fi
            echo "--$HOST | size=10 color=gray alternate=true"
        done
    fi
else
    echo "📤 Upload Latest Screenshot | disabled=true"
    echo "--Take a screenshot first | size=11 color=gray"
fi

echo "---"

# Current active server
if [ "$ACTIVE_KEY" != "none" ]; then
    echo "🖥️ Active Server: $ACTIVE_NAME | color=green"
    echo "--$ACTIVE_HOST | size=11 color=gray"
else
    echo "🖥️ Active Server: None selected | color=orange"
fi

echo "---"

# Server selector
SERVER_COUNT=$(echo "$SERVERS_INFO" | grep "^SERVER:" | wc -l | tr -d ' ')

if [ $SERVER_COUNT -gt 0 ]; then
    echo "⚙️ Change Server:"

    echo "$SERVERS_INFO" | grep "^SERVER:" | while IFS=':' read -r _ KEY NAME HOST; do
        if [ "$KEY" = "$ACTIVE_KEY" ]; then
            echo "--✓ $NAME | shell='$SCRIPT_DIR/helpers/switch-server.sh' param1='$KEY' terminal=false refresh=true"
        else
            echo "--◯ $NAME | shell='$SCRIPT_DIR/helpers/switch-server.sh' param1='$KEY' terminal=false refresh=true"
        fi
        echo "--$HOST | size=10 color=gray alternate=true"
    done
else
    echo "⚠️ No servers configured"
fi

echo "---"

# Server management
echo "⚙️ Server Management:"
echo "--➕ Add New Server... | shell='$SCRIPT_DIR/helpers/add-server.sh' terminal=false refresh=true"

if [ $SERVER_COUNT -gt 0 ]; then
    echo "--✏️ Edit Server... | shell='$SCRIPT_DIR/helpers/edit-server.sh' terminal=false refresh=true"
    echo "--🗑️ Remove Server... | shell='$SCRIPT_DIR/helpers/remove-server.sh' terminal=false refresh=true"
fi

echo "---"

# Recent uploads from log (if exists)
if [ -f /tmp/screenshot-uploader.log ]; then
    echo "📊 Recent Activity:"
    # Get last 5 upload events
    tail -20 /tmp/screenshot-uploader.log 2>/dev/null | grep -E "(Upload successful|Uploading to|detected)" | tail -5 | while read line; do
        if echo "$line" | grep -q "Upload successful"; then
            SERVER=$(echo "$line" | grep -oE "to [^!]*" | sed 's/to //')
            echo "--✅ → ${SERVER:-server} | size=11"
        elif echo "$line" | grep -q "Uploading to"; then
            SERVER=$(echo "$line" | sed 's/.*Uploading to //' | sed 's/\.\.\.//')
            echo "--⏳ → $SERVER | size=11"
        elif echo "$line" | grep -q "detected"; then
            FILE=$(echo "$line" | grep -oE "SCR-[0-9]{8}-[a-z]{4}\.png" || echo "screenshot")
            echo "--📸 $FILE | size=11"
        fi
    done | head -5
    echo "---"
fi

# Quick actions
echo "🛠️ Tools:"
echo "--📂 Open Screenshots Folder | shell='open' param1='$SCREENSHOTS_DIR' terminal=false"

if [ "$ACTIVE_KEY" != "none" ]; then
    echo "--🔐 Test SSH Connection | shell='ssh' param1='-o' param2='ConnectTimeout=5' param3='$ACTIVE_HOST' param4='echo' param5='Connection successful!' terminal=true"
fi

if [ -f /tmp/screenshot-uploader.log ]; then
    echo "--📋 View Logs | shell='tail' param1='-50' param2='/tmp/screenshot-uploader.log' terminal=true"
fi

echo "---"

# Links
echo "📖 Documentation | href='https://github.com/mdrzn/claude-screenshot-uploader'"
echo "🔄 Refresh | refresh=true"

# Version info
echo "---"
echo "v3.1 - Manual Upload | size=10 color=gray"
