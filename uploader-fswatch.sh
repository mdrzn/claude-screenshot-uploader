#!/bin/bash

# Claude Screenshot Uploader v2 - Multi-Server Support
# Automatically uploads macOS screenshots to remote servers for Claude Code access
# https://github.com/mdrzn/claude-screenshot-uploader

# Add Homebrew to PATH for fswatch
export PATH="/opt/homebrew/bin:$PATH"

# Configuration paths
CONFIG_DIR="$HOME/.claude-screenshot-uploader"
CONFIG_FILE="$CONFIG_DIR/config.json"

# Migrate old config if needed
if [ ! -f "$CONFIG_FILE" ]; then
    $(dirname "$0")/migrate-config.sh
fi

# Check config exists
if [ ! -f "$CONFIG_FILE" ]; then
    echo "❌ No configuration found. Please add a server using the menu bar icon."
    exit 1
fi

# Load configuration from JSON
CONFIG=$(cat "$CONFIG_FILE")

# Get active server
ACTIVE_SERVER=$(echo "$CONFIG" | python3 -c "
import json, sys
config = json.load(sys.stdin)
print(config.get('active', ''))
")

if [ -z "$ACTIVE_SERVER" ]; then
    echo "❌ No active server selected. Please select a server using the menu bar icon."
    exit 1
fi

# Get server details
SERVER_DETAILS=$(echo "$CONFIG" | python3 -c "
import json, sys
config = json.load(sys.stdin)
active = config.get('active', '')
if active and active in config['servers']:
    server = config['servers'][active]
    print(f\"{server['host']}|{server['user']}|{server['path']}|{server.get('auto_delete', False)}|{server.get('name', active)}\")
")

if [ -z "$SERVER_DETAILS" ]; then
    echo "❌ Could not load server configuration for: $ACTIVE_SERVER"
    exit 1
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
")

# Create remote directory if it doesn't exist
echo "🔄 Checking remote directory on $SERVER_NAME..."
if ssh "$SERVER_USER@$SERVER_HOST" "mkdir -p $SERVER_PATH && chmod 755 $SERVER_PATH" 2>/dev/null; then
    echo "✅ Remote directory ready: $SERVER_PATH"
else
    echo "⚠️  Could not verify remote directory (SSH key may be required)"
fi

echo ""
echo "🚀 Claude Screenshot Uploader Started"
echo "🖥️  Active Server: $SERVER_NAME"
echo "📁 Monitoring: $LOCAL_SCREENSHOTS"
echo "📤 Upload to: $SERVER_USER@$SERVER_HOST:$SERVER_PATH"
echo "🗑️  Auto-delete: $AUTO_DELETE"
echo "⏹️  Press Ctrl+C to stop"
echo ""

# Write current server to status file for xbar
echo "$SERVER_NAME" > /tmp/screenshot-uploader-server

# Monitor Screenshots folder for new SCR-*.png files
/opt/homebrew/bin/fswatch -0 --event Created --event Updated --event MovedTo "$LOCAL_SCREENSHOTS" 2>/dev/null | while read -d "" event; do
    # Check if config has changed (server switch)
    NEW_ACTIVE=$(cat "$CONFIG_FILE" | python3 -c "
import json, sys
config = json.load(sys.stdin)
print(config.get('active', ''))
" 2>/dev/null)
    
    if [ "$NEW_ACTIVE" != "$ACTIVE_SERVER" ] && [ -n "$NEW_ACTIVE" ]; then
        echo "🔄 Server changed, restarting..."
        exit 0
    fi
    
    # Check if the new file matches SCR-*.png pattern
    if [[ "$event" =~ SCR-[0-9]{8}-[a-z]{4}\.png$ ]]; then
        filename=$(basename "$event")
        echo "📸 New screenshot detected: $filename"
        
        # Wait a moment for file to be completely written
        sleep 0.5
        
        echo "🚀 Uploading to $SERVER_NAME..."
        
        # Create status file to indicate upload in progress (for xbar)
        echo "uploading:$filename:$SERVER_NAME" > /tmp/screenshot-uploader-status
        
        # Use rsync to upload with SSH options to prevent hanging
        rsync_output=$(rsync -av -e "ssh -o BatchMode=yes -o ConnectTimeout=5 -o StrictHostKeyChecking=no" "$event" "$SERVER_USER@$SERVER_HOST:$SERVER_PATH/" 2>&1)
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
            
            # Clear status file
            rm -f /tmp/screenshot-uploader-status
            
            # Show success notification
            osascript -e "display notification \"Uploaded to $SERVER_NAME: $filename\" with title \"Screenshot Uploaded\" subtitle \"Path copied to clipboard\""
            
            # Optional: remove local file after successful upload
            if [ "$AUTO_DELETE" = "true" ]; then
                rm "$event"
                echo "🗑️  Local file deleted"
            fi
            
        else
            echo "❌ Upload failed for $filename"
            echo "Error: $rsync_output"
            
            # Clear status file on failure too
            rm -f /tmp/screenshot-uploader-status
            
            osascript -e "display notification \"Upload failed to $SERVER_NAME\" with title \"Screenshot Upload Failed\" subtitle \"Check server connection\""
        fi
        echo ""
    fi
done