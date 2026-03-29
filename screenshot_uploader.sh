#!/bin/bash

# Claude Screenshot Uploader
# Automatically uploads macOS screenshots to remote servers for Claude Code access
# https://github.com/yourusername/claude-screenshot-uploader

# Add Homebrew to PATH for fswatch
export PATH="/opt/homebrew/bin:$PATH"

# Load configuration
CONFIG_FILE="$HOME/.claude-screenshot-uploader.conf"
if [ -f "$CONFIG_FILE" ]; then
    source "$CONFIG_FILE"
else
    echo "❌ Configuration file not found: $CONFIG_FILE"
    echo "Please create it from config.example.sh"
    exit 1
fi

# Default values if not set in config
: ${SERVER_HOST:="your-server.com"}
: ${SERVER_USER:="your-username"}
: ${SERVER_PATH:="/tmp/screenshots"}
: ${LOCAL_SCREENSHOTS:="$HOME/Screenshots"}
: ${AUTO_DELETE:="false"}

# Validate configuration
if [ "$SERVER_HOST" = "your-server.com" ]; then
    echo "❌ Please configure SERVER_HOST in $CONFIG_FILE"
    exit 1
fi

# Create remote directory if it doesn't exist
echo "🔄 Checking remote directory..."
if ssh "$SERVER_USER@$SERVER_HOST" "mkdir -p $SERVER_PATH && chmod 755 $SERVER_PATH" 2>/dev/null; then
    echo "✅ Remote directory ready: $SERVER_PATH"
else
    echo "⚠️  Could not verify remote directory (SSH key may be required)"
fi

echo ""
echo "🚀 Claude Screenshot Uploader Started"
echo "📁 Monitoring: $LOCAL_SCREENSHOTS"
echo "📤 Upload to: $SERVER_USER@$SERVER_HOST:$SERVER_PATH"
echo "🗑️  Auto-delete: $AUTO_DELETE"
echo "⏹️  Press Ctrl+C to stop"
echo ""

# Monitor Screenshots folder for new SCR-*.png files
/opt/homebrew/bin/fswatch -0 --event Created --event Updated --event MovedTo --event Renamed "$LOCAL_SCREENSHOTS" 2>/dev/null | while read -d "" event; do
    # Skip temporary dotfiles (macOS writes .Screenshot... then renames)
    filename=$(basename "$event")
    [[ "$filename" == .* ]] && continue

    # Check if the new file is a screenshot (supports both naming formats)
    # macOS default: "Screenshot YYYY-MM-DD at H.MM.SS AM.png"
    # macOS Sequoia: "SCR-YYYYMMDD-xxxx.png"
    if [[ "$filename" =~ ^(Screenshot[[:space:]].*\.png|SCR-[0-9]{8}-[a-z]{4}\.png)$ ]]; then
        echo "📸 New screenshot detected: $filename"

        # Wait for file to be completely written
        sleep 1
        
        # Sanitize filename: replace Unicode narrow no-break space (U+202F) with regular space
        clean_filename=$(echo "$filename" | sed "s/$(printf '\xe2\x80\xaf')/ /g")

        echo "🚀 Uploading to server..."

        # Create status file to indicate upload in progress (for xbar)
        echo "uploading:$clean_filename" > /tmp/screenshot-uploader-status

        # Upload with scp, renaming to sanitized filename
        scp_output=$(scp -o BatchMode=yes -o ConnectTimeout=5 -o StrictHostKeyChecking=no "$event" "$SERVER_USER@$SERVER_HOST:$SERVER_PATH/$clean_filename" 2>&1)
        scp_exit=$?

        # Keep status file visible for at least 1 second so xbar can see it
        sleep 1

        # Check if upload was successful
        if [ $scp_exit -eq 0 ]; then
            # Copy server path to clipboard
            server_file_path="$SERVER_PATH/$clean_filename"
            echo -n "$server_file_path" | pbcopy
            
            echo "✅ Upload successful!"
            echo "📋 Server path copied to clipboard: $server_file_path"
            
            # Clear status file
            rm -f /tmp/screenshot-uploader-status
            
            # Show success notification
            osascript -e "display notification \"Path copied to clipboard: $clean_filename\" with title \"Screenshot Uploaded\" subtitle \"Ready to paste in Claude Code\""
            
            # Optional: remove local file after successful upload
            if [ "$AUTO_DELETE" = "true" ]; then
                rm "$event"
                echo "🗑️  Local file deleted"
            fi
            
        else
            echo "❌ Upload failed for $clean_filename"
            echo "Error: $scp_output"
            
            # Clear status file on failure too
            rm -f /tmp/screenshot-uploader-status
            
            osascript -e "display notification \"Upload failed - check logs\" with title \"Claude Screenshot\" subtitle \"Check server connection\""
        fi
        echo ""
    fi
done