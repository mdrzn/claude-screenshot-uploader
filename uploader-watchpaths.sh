#!/bin/bash

# Claude Screenshot Uploader v2 - WatchPaths Version
# Uploads the most recent screenshot when triggered by launchd WatchPaths

# Add Homebrew to PATH
export PATH="/opt/homebrew/bin:$PATH"

# Configuration paths
CONFIG_DIR="$HOME/.claude-screenshot-uploader"
CONFIG_FILE="$CONFIG_DIR/config.json"

# Check config exists
if [ ! -f "$CONFIG_FILE" ]; then
    exit 0  # Silent exit if no config
fi

# Load configuration
CONFIG=$(cat "$CONFIG_FILE")

# Get active server
ACTIVE_SERVER=$(echo "$CONFIG" | python3 -c "
import json, sys
config = json.load(sys.stdin)
print(config.get('active', ''))
" 2>/dev/null)

if [ -z "$ACTIVE_SERVER" ]; then
    exit 0
fi

# Get server details
SERVER_DETAILS=$(echo "$CONFIG" | python3 -c "
import json, sys
config = json.load(sys.stdin)
active = config.get('active', '')
if active and active in config['servers']:
    server = config['servers'][active]
    print(f\"{server['host']}|{server['user']}|{server['path']}|{server.get('auto_delete', False)}|{server.get('name', active)}\")
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
config = json.load(sys.stdin)
path = config.get('local_screenshots', '$HOME/Screenshots')
print(os.path.expandvars(path))
" 2>/dev/null)

# Write current server to status file for xbar
echo "$SERVER_NAME" > /tmp/screenshot-uploader-server

# Find the most recent SCR-*.png file
recent_screenshot=$(ls -t "$LOCAL_SCREENSHOTS"/SCR-*.png 2>/dev/null | head -1)

# If no recent screenshot found, exit
if [ -z "$recent_screenshot" ]; then
    exit 0
fi

filename=$(basename "$recent_screenshot")

# Check if we've already uploaded this file (prevent duplicates)
LAST_UPLOADED_FILE="/tmp/screenshot-uploader-last"
if [ -f "$LAST_UPLOADED_FILE" ]; then
    last_uploaded=$(cat "$LAST_UPLOADED_FILE")
    if [ "$filename" = "$last_uploaded" ]; then
        exit 0  # Already uploaded
    fi
fi

echo "📸 New screenshot detected: $filename"
echo "🚀 Uploading to $SERVER_NAME..."

# Create status file to indicate upload in progress (for xbar)
echo "uploading:$filename:$SERVER_NAME" > /tmp/screenshot-uploader-status

# Use rsync to upload
rsync_output=$(rsync -av -e "ssh -o BatchMode=yes -o ConnectTimeout=5 -o StrictHostKeyChecking=no" "$recent_screenshot" "$SERVER_USER@$SERVER_HOST:$SERVER_PATH/" 2>&1)
rsync_exit=$?

# Keep status file visible for at least 1 second so xbar can see it
sleep 1

# Check if upload was successful
if [ $rsync_exit -eq 0 ] && echo "$rsync_output" | grep -q "$filename"; then
    # Copy server path to clipboard
    server_file_path="$SERVER_PATH/$filename"
    echo -n "$server_file_path" | pbcopy

    echo "✅ Upload successful to $SERVER_NAME!"
    echo "📋 Server path copied to clipboard: $server_file_path"

    # Save this as last uploaded file
    echo "$filename" > "$LAST_UPLOADED_FILE"

    # Clear status file
    rm -f /tmp/screenshot-uploader-status

    # Show success notification
    osascript -e "display notification \"Uploaded to $SERVER_NAME: $filename\" with title \"Screenshot Uploaded\" subtitle \"Path copied to clipboard\""

    # Optional: remove local file after successful upload
    if [ "$AUTO_DELETE" = "true" ]; then
        rm "$recent_screenshot"
        echo "🗑️  Local file deleted"
    fi
else
    echo "❌ Upload failed for $filename"
    echo "Error: $rsync_output"

    # Clear status file on failure
    rm -f /tmp/screenshot-uploader-status

    osascript -e "display notification \"Upload failed to $SERVER_NAME\" with title \"Screenshot Upload Failed\" subtitle \"Check server connection\""
fi
