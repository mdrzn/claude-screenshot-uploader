#!/bin/bash

# Edit an existing server profile
CONFIG_FILE="$HOME/.claude-screenshot-uploader/config.json"

# Get list of servers with their current details
SERVERS=$(python3 << 'EOF'
import json
import os
config_file = os.path.expanduser("~/.claude-screenshot-uploader/config.json")
try:
    with open(config_file, 'r') as f:
        config = json.load(f)
    for key, server in config['servers'].items():
        print(f"{server.get('name', key)}")
except:
    pass
EOF
)

if [ -z "$SERVERS" ]; then
    osascript -e 'display alert "No Servers" message "No servers configured. Please add a server first." as informational'
    exit 1
fi

# Let user choose which server to edit
SERVER_NAME=$(osascript -e "choose from list {$(echo "$SERVERS" | sed 's/^/"/; s/$/",/' | tr '\n' ' ' | sed 's/, $//')} with prompt \"Select server to edit:\" with title \"Edit Server\"" -e 'result' 2>/dev/null)

if [ -z "$SERVER_NAME" ] || [ "$SERVER_NAME" = "false" ]; then
    echo "Cancelled"
    exit 1
fi

# Get current server details
SERVER_DETAILS=$(python3 << EOF
import json
config_file = "$CONFIG_FILE"
server_name = "$SERVER_NAME"

with open(config_file, 'r') as f:
    config = json.load(f)

for key, server in config['servers'].items():
    if server.get('name', key) == server_name:
        print(f"{key}|{server['host']}|{server['user']}|{server['path']}|{server.get('auto_delete', False)}")
        break
EOF
)

IFS='|' read -r SERVER_KEY CURRENT_HOST CURRENT_USER CURRENT_PATH CURRENT_AUTO_DELETE <<< "$SERVER_DETAILS"

# Get new details via AppleScript dialogs (showing current values)
NEW_HOST=$(osascript -e "display dialog \"Server hostname or IP:\" default answer \"$CURRENT_HOST\" with title \"Edit Server - Host\" with icon note" -e 'text returned of result' 2>/dev/null)

if [ -z "$NEW_HOST" ]; then
    echo "Cancelled"
    exit 1
fi

NEW_USER=$(osascript -e "display dialog \"SSH username:\" default answer \"$CURRENT_USER\" with title \"Edit Server - User\" with icon note" -e 'text returned of result' 2>/dev/null)

if [ -z "$NEW_USER" ]; then
    echo "Cancelled"
    exit 1
fi

NEW_PATH=$(osascript -e "display dialog \"Remote path for screenshots:\" default answer \"$CURRENT_PATH\" with title \"Edit Server - Path\" with icon note" -e 'text returned of result' 2>/dev/null)

if [ -z "$NEW_PATH" ]; then
    echo "Cancelled"
    exit 1
fi

if [ "$CURRENT_AUTO_DELETE" = "True" ]; then
    DEFAULT_BUTTON="Yes"
else
    DEFAULT_BUTTON="No"
fi

NEW_AUTO_DELETE=$(osascript -e "button returned of (display dialog \"Delete local screenshots after upload?\" buttons {\"No\", \"Yes\"} default button \"$DEFAULT_BUTTON\" with title \"Edit Server - Options\" with icon note)" 2>/dev/null)

if [ "$NEW_AUTO_DELETE" = "Yes" ]; then
    NEW_AUTO_DELETE="true"
else
    NEW_AUTO_DELETE="false"
fi

# Update server config using Python
python3 << EOF
import json

config_file = "$CONFIG_FILE"
server_key = "$SERVER_KEY"

with open(config_file, 'r') as f:
    config = json.load(f)

# Update server details
config['servers'][server_key]['host'] = '$NEW_HOST'
config['servers'][server_key]['user'] = '$NEW_USER'
config['servers'][server_key]['path'] = '$NEW_PATH'
config['servers'][server_key]['auto_delete'] = $NEW_AUTO_DELETE

with open(config_file, 'w') as f:
    json.dump(config, f, indent=2)

print("✅ Server updated successfully")
EOF

osascript -e "display notification \"Server '$SERVER_NAME' updated\" with title \"Server Updated\""