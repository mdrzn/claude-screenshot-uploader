#!/bin/bash

# Switch active server
CONFIG_FILE="$HOME/.claude-screenshot-uploader/config.json"
SERVER_KEY="$1"

# Debug logging
echo "$(date): switch-server.sh called with args: [$*] argc=$#" >> /tmp/screenshot-uploader-debug.log

if [ -z "$SERVER_KEY" ]; then
    echo "$(date): ERROR - no server key provided" >> /tmp/screenshot-uploader-debug.log
    echo "Usage: $0 <server_key>"
    exit 1
fi

echo "$(date): Switching to server key: '$SERVER_KEY'" >> /tmp/screenshot-uploader-debug.log

# Update active server using Python
python3 << EOF
import json
import sys

config_file = "$CONFIG_FILE"
server_key = "$SERVER_KEY"

try:
    with open(config_file, 'r') as f:
        config = json.load(f)
    
    if server_key in config['servers']:
        config['active'] = server_key
        
        with open(config_file, 'w') as f:
            json.dump(config, f, indent=2)
        
        server_name = config['servers'][server_key].get('name', server_key)
        print(f"✅ Switched to: {server_name}")
        
        # Show notification
        import subprocess
        subprocess.run(['osascript', '-e', f'display notification "Active server: {server_name}" with title "Server Switched"'])
    else:
        print(f"❌ Server '{server_key}' not found")
        sys.exit(1)
except Exception as e:
    print(f"❌ Error: {e}")
    sys.exit(1)
EOF

# Restart the service to use new server
launchctl stop com.claudecode.screenshot-uploader 2>/dev/null