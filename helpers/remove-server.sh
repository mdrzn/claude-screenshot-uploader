#!/bin/bash

# Remove a server profile
CONFIG_FILE="$HOME/.claude-screenshot-uploader/config.json"

# Get list of servers
SERVERS=$(python3 << 'EOF'
import json
config_file = "$HOME/.claude-screenshot-uploader/config.json"
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
    osascript -e 'display alert "No Servers" message "No servers configured." as informational'
    exit 1
fi

# Let user choose which server to remove
SERVER_NAME=$(osascript -e "choose from list {$(echo "$SERVERS" | sed 's/^/"/; s/$/",/' | tr '\n' ' ' | sed 's/, $//')} with prompt \"Select server to remove:\" with title \"Remove Server\"" -e 'result' 2>/dev/null)

if [ -z "$SERVER_NAME" ] || [ "$SERVER_NAME" = "false" ]; then
    echo "Cancelled"
    exit 1
fi

# Confirm deletion
CONFIRM=$(osascript -e "button returned of (display dialog \"Are you sure you want to remove the server '$SERVER_NAME'?\" buttons {\"Cancel\", \"Remove\"} default button \"Cancel\" with title \"Confirm Removal\" with icon caution)" 2>/dev/null)

if [ "$CONFIRM" != "Remove" ]; then
    echo "Cancelled"
    exit 1
fi

# Remove server using Python
python3 << EOF
import json
import sys

config_file = "$CONFIG_FILE"
server_name = "$SERVER_NAME"

try:
    with open(config_file, 'r') as f:
        config = json.load(f)
    
    # Find server key by name
    server_key = None
    for key, server in config['servers'].items():
        if server.get('name', key) == server_name:
            server_key = key
            break
    
    if server_key:
        del config['servers'][server_key]
        
        # If this was the active server, clear active
        if config.get('active') == server_key:
            # Set to first remaining server or empty
            if config['servers']:
                config['active'] = list(config['servers'].keys())[0]
            else:
                config['active'] = ""
        
        with open(config_file, 'w') as f:
            json.dump(config, f, indent=2)
        
        print(f"✅ Server '{server_name}' removed")
        
        # Show notification
        import subprocess
        subprocess.run(['osascript', '-e', f'display notification "Server removed: {server_name}" with title "Server Removed"'])
    else:
        print(f"❌ Server '{server_name}' not found")
        sys.exit(1)
except Exception as e:
    print(f"❌ Error: {e}")
    sys.exit(1)
EOF