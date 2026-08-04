#!/bin/bash

# Quick edit for the active server
CONFIG_FILE="$HOME/.claude-screenshot-uploader/config.json"

# Get current config
if [ ! -f "$CONFIG_FILE" ]; then
    echo "No config file found"
    exit 1
fi

# Read current values using jq or python
CURRENT_VALUES=$(python3 -c "
import json
with open('$CONFIG_FILE', 'r') as f:
    config = json.load(f)
    active = config.get('active', '')
    if active and active in config['servers']:
        s = config['servers'][active]
        print(f\"{s.get('name', active)}|{s['host']}|{s['user']}|{s['path']}|{s.get('auto_delete', False)}\")
")

if [ -z "$CURRENT_VALUES" ]; then
    osascript -e 'display alert "No Active Server" message "Please select a server first." as warning'
    exit 1
fi

IFS='|' read -r CURRENT_NAME CURRENT_HOST CURRENT_USER CURRENT_PATH CURRENT_DELETE <<< "$CURRENT_VALUES"

# Get new values via dialogs
NEW_NAME=$(osascript -e "display dialog \"Server display name:\" default answer \"$CURRENT_NAME\" with title \"Edit Server - Name\" with icon note" -e 'text returned of result' 2>/dev/null)
[ -z "$NEW_NAME" ] && exit 1
NEW_HOST=$(osascript -e "display dialog \"Server hostname or IP:\" default answer \"$CURRENT_HOST\" with title \"Edit Server\" with icon note" -e 'text returned of result' 2>/dev/null)
[ -z "$NEW_HOST" ] && exit 1

NEW_USER=$(osascript -e "display dialog \"SSH username:\" default answer \"$CURRENT_USER\" with title \"Edit Server\" with icon note" -e 'text returned of result' 2>/dev/null)
[ -z "$NEW_USER" ] && exit 1

NEW_PATH=$(osascript -e "display dialog \"Remote path:\" default answer \"$CURRENT_PATH\" with title \"Edit Server\" with icon note" -e 'text returned of result' 2>/dev/null)
[ -z "$NEW_PATH" ] && exit 1

# Update config
python3 -c "
import json
with open('$CONFIG_FILE', 'r') as f:
    config = json.load(f)
active = config.get('active', '')
if active in config['servers']:
    config['servers'][active]['name'] = '$NEW_NAME'
    config['servers'][active]['host'] = '$NEW_HOST'
    config['servers'][active]['user'] = '$NEW_USER'
    config['servers'][active]['path'] = '$NEW_PATH'
    with open('$CONFIG_FILE', 'w') as f:
        json.dump(config, f, indent=2)
    print('✅ Server updated')
"

osascript -e 'display notification "Server configuration updated" with title "Server Updated"'

# Restart service
launchctl stop com.claudecode.screenshot-uploader 2>/dev/null