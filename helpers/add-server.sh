#!/bin/bash

# Add a new server profile via GUI dialog
CONFIG_DIR="$HOME/.claude-screenshot-uploader"
CONFIG_FILE="$CONFIG_DIR/config.json"

# Ensure config exists
if [ ! -f "$CONFIG_FILE" ]; then
    $(dirname "$0")/../migrate-config.sh
fi

# Get server details via AppleScript dialogs
SERVER_NAME=$(osascript -e 'display dialog "Enter a name for this server profile:" default answer "My Server" with title "Add Server" with icon note' -e 'text returned of result' 2>/dev/null)

if [ -z "$SERVER_NAME" ]; then
    echo "Cancelled"
    exit 1
fi

# Check if name already exists
if grep -q "\"$SERVER_NAME\"" "$CONFIG_FILE" 2>/dev/null; then
    osascript -e "display alert \"Server Exists\" message \"A server named '$SERVER_NAME' already exists.\" as warning"
    exit 1
fi

SERVER_HOST=$(osascript -e 'display dialog "Enter server hostname or IP:" default answer "example.com" with title "Add Server - Host" with icon note' -e 'text returned of result' 2>/dev/null)

if [ -z "$SERVER_HOST" ]; then
    echo "Cancelled"
    exit 1
fi

SERVER_USER=$(osascript -e 'display dialog "Enter SSH username:" default answer "username" with title "Add Server - User" with icon note' -e 'text returned of result' 2>/dev/null)

if [ -z "$SERVER_USER" ]; then
    echo "Cancelled"
    exit 1
fi

SERVER_PATH=$(osascript -e 'display dialog "Enter remote path for screenshots:" default answer "/tmp/screenshots" with title "Add Server - Path" with icon note' -e 'text returned of result' 2>/dev/null)

if [ -z "$SERVER_PATH" ]; then
    echo "Cancelled"
    exit 1
fi

AUTO_DELETE=$(osascript -e 'button returned of (display dialog "Delete local screenshots after upload?" buttons {"No", "Yes"} default button "No" with title "Add Server - Options" with icon note)' 2>/dev/null)

if [ "$AUTO_DELETE" = "Yes" ]; then
    AUTO_DELETE="true"
else
    AUTO_DELETE="false"
fi

# Create a safe key from the server name (alphanumeric + underscore)
SERVER_KEY=$(echo "$SERVER_NAME" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9]/_/g')

# Add server to config using Python for JSON manipulation
python3 << EOF
import json
import sys

config_file = "$CONFIG_FILE"

# Read existing config
with open(config_file, 'r') as f:
    config = json.load(f)

# Add new server
config['servers']['$SERVER_KEY'] = {
    'name': '$SERVER_NAME',
    'host': '$SERVER_HOST',
    'user': '$SERVER_USER',
    'path': '$SERVER_PATH',
    'auto_delete': $AUTO_DELETE
}

# If no active server, set this as active
if not config.get('active'):
    config['active'] = '$SERVER_KEY'

# Write updated config
with open(config_file, 'w') as f:
    json.dump(config, f, indent=2)

print("✅ Server added successfully")
EOF

# Test SSH connection
echo "Testing connection to $SERVER_USER@$SERVER_HOST..."
if ssh -o BatchMode=yes -o ConnectTimeout=5 "$SERVER_USER@$SERVER_HOST" exit 2>/dev/null; then
    osascript -e "display notification \"Server '$SERVER_NAME' added successfully\" with title \"Claude Screenshot Uploader\" subtitle \"SSH connection verified\""
else
    osascript -e "display alert \"Warning\" message \"Server added but SSH connection failed. You may need to set up SSH keys:\n\nssh-copy-id $SERVER_USER@$SERVER_HOST\" as warning"
fi