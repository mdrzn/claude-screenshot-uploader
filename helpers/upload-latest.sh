#!/bin/bash

# Upload Latest Screenshot Helper
# Finds the most recent screenshot and uploads it to the specified server

CONFIG_FILE="$HOME/.claude-screenshot-uploader/config.json"
STATUS_FILE="/tmp/screenshot-uploader-status"
SCREENSHOTS_DIR="$HOME/Screenshots"

# Get server key from argument, or use active server if not specified
SERVER_KEY="$1"

if [ -z "$SERVER_KEY" ]; then
    # Get active server from config
    SERVER_KEY=$(python3 << 'EOF'
import json
import sys
import os

config_file = os.path.expanduser("~/.claude-screenshot-uploader/config.json")

try:
    with open(config_file, 'r') as f:
        config = json.load(f)

    active = config.get('active', '')
    if active:
        print(active)
    else:
        sys.exit(1)
except Exception as e:
    sys.exit(1)
EOF
    )

    if [ -z "$SERVER_KEY" ]; then
        osascript -e 'display notification "No server selected" with title "Upload Failed" subtitle "Please select a server first"'
        exit 1
    fi
fi

# Get server configuration
SERVER_INFO=$(python3 << EOF
import json
import sys
import os

config_file = os.path.expanduser("$CONFIG_FILE")
server_key = "$SERVER_KEY"

try:
    with open(config_file, 'r') as f:
        config = json.load(f)

    if server_key not in config['servers']:
        print(f"ERROR:Server '{server_key}' not found")
        sys.exit(1)

    server = config['servers'][server_key]
    print(f"{server.get('name', server_key)}|{server['host']}|{server['user']}|{server['path']}")
except Exception as e:
    print(f"ERROR:{e}")
    sys.exit(1)
EOF
)

if [[ "$SERVER_INFO" == ERROR:* ]]; then
    osascript -e "display notification \"${SERVER_INFO#ERROR:}\" with title \"Upload Failed\""
    exit 1
fi

IFS='|' read -r SERVER_NAME SERVER_HOST SERVER_USER SERVER_PATH <<< "$SERVER_INFO"

# Find the most recent screenshot
LATEST_SCREENSHOT=$(find "$SCREENSHOTS_DIR" -maxdepth 1 -type f \( -name "SCR-*.png" -o -name "SCR-*.jpeg" -o -name "Screenshot *.png" -o -name "Screenshot *.jpg" -o -name "Screenshot *.jpeg" \) -print0 | xargs -0 ls -t | head -n 1)

if [ -z "$LATEST_SCREENSHOT" ]; then
    osascript -e 'display notification "No screenshots found in ~/Screenshots" with title "Upload Failed" subtitle "Take a screenshot first"'
    exit 1
fi

FILENAME=$(basename "$LATEST_SCREENSHOT")

echo "📸 Found: $FILENAME"
echo "🚀 Uploading to $SERVER_NAME ($SERVER_HOST)..."

# Create status file to indicate upload in progress
echo "uploading:$FILENAME:$SERVER_NAME" > "$STATUS_FILE"

# Upload using rsync
rsync_output=$(rsync -av -e "ssh -o BatchMode=yes -o ConnectTimeout=5 -o StrictHostKeyChecking=no" "$LATEST_SCREENSHOT" "$SERVER_USER@$SERVER_HOST:$SERVER_PATH/" 2>&1)
rsync_exit=$?

# Keep status file visible for at least 1 second so xbar can see it
sleep 1

# Check if upload was successful
if [ $rsync_exit -eq 0 ]; then
    # Copy server path to clipboard
    server_file_path="$SERVER_PATH/$FILENAME"
    echo -n "$server_file_path" | pbcopy

    echo "✅ Upload successful!"
    echo "📋 Server path copied to clipboard: $server_file_path"

    # Clear status file
    rm -f "$STATUS_FILE"

    # Show success notification
    osascript -e "display notification \"Path copied to clipboard: $FILENAME\" with title \"Screenshot Uploaded\" subtitle \"To: $SERVER_NAME\""

    exit 0
else
    echo "❌ Upload failed for $FILENAME"
    echo "Error: $rsync_output"

    # Clear status file on failure
    rm -f "$STATUS_FILE"

    osascript -e "display notification \"Upload failed - check SSH connection\" with title \"Upload Failed\" subtitle \"Server: $SERVER_NAME\""

    exit 1
fi
