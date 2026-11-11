#!/bin/bash

# Switch the active server.
# Usage: switch-server.sh <server_key>

source "$(dirname "$0")/common.sh"

SERVER_KEY="$1"

if [ -z "$SERVER_KEY" ]; then
    echo "Usage: $0 <server_key>" >&2
    exit 1
fi

SERVER_NAME=$(python3 - "$CSU_CONFIG_FILE" "$SERVER_KEY" <<'PY'
import json, os, sys

path, key = sys.argv[1], sys.argv[2]

with open(path) as handle:
    config = json.load(handle)

servers = config.get('servers') or {}
if key not in servers:
    sys.stderr.write("Server '%s' not found\n" % key)
    sys.exit(1)

config['active'] = key

# Write via a temporary file so an interrupted write can't truncate the config
# and take every configured server with it.
tmp = path + '.tmp'
with open(tmp, 'w') as handle:
    json.dump(config, handle, indent=2)
os.replace(tmp, path)

print(servers[key].get('name', key))
PY
)

if [ $? -ne 0 ] || [ -z "$SERVER_NAME" ]; then
    osascript -e "display alert \"Switch Failed\" message \"Could not switch to '$SERVER_KEY'.\" as warning" 2>/dev/null
    exit 1
fi

csu_log "🔀 Active server → $SERVER_NAME"
osascript -e "display notification \"Active server: $SERVER_NAME\" with title \"Server Switched\"" 2>/dev/null

# Let a running auto-upload daemon pick up the new server.
csu_restart_daemon
