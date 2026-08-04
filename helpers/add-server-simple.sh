#!/bin/bash

# Simplified add server script
CONFIG_FILE="$HOME/.claude-screenshot-uploader/config.json"

# Ensure config exists
if [ ! -f "$CONFIG_FILE" ]; then
    mkdir -p "$(dirname "$CONFIG_FILE")"
    echo '{"active": "", "servers": {}, "local_screenshots": "$HOME/Screenshots"}' > "$CONFIG_FILE"
fi

# Get server details via AppleScript dialogs
SERVER_NAME=$(osascript -e 'display dialog "Enter a display name for this server:\n(e.g. \"Production Server\", \"Dev Environment\")" default answer "My Server" with title "Add Server - Name" with icon note' -e 'text returned of result' 2>/dev/null)
[ -z "$SERVER_NAME" ] && exit 1

SERVER_HOST=$(osascript -e 'display dialog "Enter server hostname or IP:" default answer "example.com" with title "Add Server - Host" with icon note' -e 'text returned of result' 2>/dev/null)
[ -z "$SERVER_HOST" ] && exit 1

SERVER_USER=$(osascript -e 'display dialog "Enter SSH username:" default answer "username" with title "Add Server - User" with icon note' -e 'text returned of result' 2>/dev/null)
[ -z "$SERVER_USER" ] && exit 1

SERVER_PATH=$(osascript -e 'display dialog "Enter remote path for screenshots:" default answer "/tmp/screenshots" with title "Add Server - Path" with icon note' -e 'text returned of result' 2>/dev/null)
[ -z "$SERVER_PATH" ] && exit 1

# Create a safe key from the server name
SERVER_KEY=$(echo "$SERVER_NAME" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9]/_/g')

# Create temporary Python script to update JSON
cat > /tmp/add_server.py << PYEOF
import json
import sys

config_file = "$CONFIG_FILE"

# Read existing config
try:
    with open(config_file, 'r') as f:
        config = json.load(f)
except:
    config = {"active": "", "servers": {}, "local_screenshots": "$HOME/Screenshots"}

# Add new server
config['servers']['$SERVER_KEY'] = {
    'name': '$SERVER_NAME',
    'host': '$SERVER_HOST',
    'user': '$SERVER_USER',
    'path': '$SERVER_PATH',
    'auto_delete': False
}

# If no active server, set this as active
if not config.get('active'):
    config['active'] = '$SERVER_KEY'

# Write updated config
with open(config_file, 'w') as f:
    json.dump(config, f, indent=2)

print("✅ Server added successfully")
PYEOF

# Run the Python script
python3 /tmp/add_server.py
rm -f /tmp/add_server.py

# Show notification
osascript -e "display notification \"Server '$SERVER_NAME' added successfully\" with title \"Claude Screenshot Uploader\""

# Restart service if running
launchctl stop com.claudecode.screenshot-uploader 2>/dev/null