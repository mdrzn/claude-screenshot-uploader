#!/bin/bash

# Claude Screenshot Uploader v3 - Polling Version (Bulletproof for macOS Sequoia)
# Runs every 2 seconds to check for new screenshots

# Add Homebrew to PATH
export PATH="/opt/homebrew/bin:$PATH"

# Configuration paths
CONFIG_DIR="$HOME/.claude-screenshot-uploader"
CONFIG_FILE="$CONFIG_DIR/config.json"
LAST_UPLOADED_FILE="/tmp/screenshot-uploader-last-uploaded"
TIMESTAMP_FILE="/tmp/screenshot-uploader-last-check"

# Silent exit if no config
if [ ! -f "$CONFIG_FILE" ]; then
    exit 0
fi

# Load configuration
CONFIG=$(cat "$CONFIG_FILE" 2>/dev/null)
if [ -z "$CONFIG" ]; then
    exit 0
fi

# Get active server
ACTIVE_SERVER=$(echo "$CONFIG" | python3 -c "
import json, sys
try:
    config = json.load(sys.stdin)
    print(config.get('active', ''))
except:
    pass
" 2>/dev/null)

if [ -z "$ACTIVE_SERVER" ]; then
    exit 0
fi

# Get server details
SERVER_DETAILS=$(echo "$CONFIG" | python3 -c "
import json, sys
try:
    config = json.load(sys.stdin)
    active = config.get('active', '')
    if active and active in config['servers']:
        server = config['servers'][active]
        print(f\"{server['host']}|{server['user']}|{server['path']}|{server.get('auto_delete', False)}|{server.get('name', active)}\")
except:
    pass
" 2>/dev/null)

if [ -z "$SERVER_DETAILS" ]; then
    exit 0
fi

# Parse server details
IFS='|' read -r SERVER_HOST SERVER_USER SERVER_PATH AUTO_DELETE SERVER_NAME <<< "$SERVER_DETAILS"

# Convert Python boolean to bash
if [ "$AUTO_DELETE" = "True" ]; then
    AUTO_DELETE="true"
else
    AUTO_DELETE="false"
fi

# Get local screenshots path
LOCAL_SCREENSHOTS=$(echo "$CONFIG" | python3 -c "
import json, sys, os
try:
    config = json.load(sys.stdin)
    path = config.get('local_screenshots', '$HOME/Screenshots')
    print(os.path.expandvars(path))
except:
    print('$HOME/Screenshots')
" 2>/dev/null)

# Write current server to status file for xbar
echo "$SERVER_NAME" > /tmp/screenshot-uploader-server

# Find the most recent SCR-*.png file
recent_screenshot=$(ls -t "$LOCAL_SCREENSHOTS"/SCR-*.png 2>/dev/null | head -1)

# Exit if no screenshot found
if [ -z "$recent_screenshot" ]; then
    exit 0
fi

filename=$(basename "$recent_screenshot")

# Check if this file was already uploaded
if [ -f "$LAST_UPLOADED_FILE" ]; then
    last_uploaded=$(cat "$LAST_UPLOADED_FILE" 2>/dev/null)
    if [ "$filename" = "$last_uploaded" ]; then
        exit 0  # Already uploaded
    fi
fi

# Check if file is recent (modified within last 10 seconds)
if [ "$(uname)" = "Darwin" ]; then
    file_age=$(( $(date +%s) - $(stat -f %m "$recent_screenshot" 2>/dev/null || echo 0) ))
else
    file_age=$(( $(date +%s) - $(stat -c %Y "$recent_screenshot" 2>/dev/null || echo 0) ))
fi

# Only upload if file is less than 10 seconds old (prevents re-uploading old screenshots on restart)
if [ "$file_age" -gt 10 ]; then
    exit 0
fi

# Upload the screenshot
echo "📸 New screenshot detected: $filename" >> /tmp/screenshot-uploader.log
echo "🚀 Uploading to $SERVER_NAME..." >> /tmp/screenshot-uploader.log

# Create status file for xbar
echo "uploading:$filename:$SERVER_NAME" > /tmp/screenshot-uploader-status

# Use rsync to upload
rsync_output=$(rsync -av -e "ssh -o BatchMode=yes -o ConnectTimeout=5 -o StrictHostKeyChecking=no" "$recent_screenshot" "$SERVER_USER@$SERVER_HOST:$SERVER_PATH/" 2>&1)
rsync_exit=$?

# Keep status file visible for at least 1 second
sleep 1

# Check if upload was successful
if [ $rsync_exit -eq 0 ] && echo "$rsync_output" | grep -q "$filename"; then
    # Copy server path to clipboard
    server_file_path="$SERVER_PATH/$filename"
    echo -n "$server_file_path" | pbcopy

    echo "✅ Upload successful to $SERVER_NAME!" >> /tmp/screenshot-uploader.log
    echo "📋 Server path copied to clipboard: $server_file_path" >> /tmp/screenshot-uploader.log

    # Save as last uploaded
    echo "$filename" > "$LAST_UPLOADED_FILE"

    # Clear status file
    rm -f /tmp/screenshot-uploader-status

    # Show notification
    osascript -e "display notification \"Uploaded to $SERVER_NAME: $filename\" with title \"Screenshot Uploaded\" subtitle \"Path copied to clipboard\"" 2>/dev/null

    # Optional: remove local file
    if [ "$AUTO_DELETE" = "true" ]; then
        rm "$recent_screenshot"
        echo "🗑️  Local file deleted" >> /tmp/screenshot-uploader.log
    fi
else
    echo "❌ Upload failed for $filename" >> /tmp/screenshot-uploader.log
    echo "Error: $rsync_output" >> /tmp/screenshot-uploader.log

    rm -f /tmp/screenshot-uploader-status

    osascript -e "display notification \"Upload failed to $SERVER_NAME\" with title \"Screenshot Upload Failed\" subtitle \"Check server connection\"" 2>/dev/null
fi
