#!/bin/bash

# Remove a server profile, chosen from a list.

source "$(dirname "$0")/common.sh"

CONFIG_ROWS="$(csu_config_dump)"
if [ -z "$CONFIG_ROWS" ] || printf '%s\n' "$CONFIG_ROWS" | grep -q '^ERROR'; then
    osascript -e 'display alert "No Servers" message "No servers are configured." as informational' 2>/dev/null
    exit 1
fi

# Build the AppleScript list literal from the configured server names.
LIST_ITEMS="$(printf '%s\n' "$CONFIG_ROWS" | awk -F'\t' '
    $1 == "SERVER" {
        name = $3
        gsub(/"/, "", name)          # quotes would break the AppleScript literal
        printf "%s\"%s\"", (n++ ? ", " : ""), name
    }')"

if [ -z "$LIST_ITEMS" ]; then
    osascript -e 'display alert "No Servers" message "No servers are configured." as informational' 2>/dev/null
    exit 1
fi

SERVER_NAME=$(osascript \
    -e "choose from list {$LIST_ITEMS} with prompt \"Select server to remove:\" with title \"Remove Server\"" \
    -e 'result' 2>/dev/null)

if [ -z "$SERVER_NAME" ] || [ "$SERVER_NAME" = "false" ]; then
    echo "Cancelled"
    exit 0
fi

CONFIRM=$(osascript -e "button returned of (display dialog \"Remove the server '$SERVER_NAME'?\" buttons {\"Cancel\", \"Remove\"} default button \"Cancel\" with title \"Confirm Removal\" with icon caution)" 2>/dev/null)

if [ "$CONFIRM" != "Remove" ]; then
    echo "Cancelled"
    exit 0
fi

python3 - "$CSU_CONFIG_FILE" "$SERVER_NAME" <<'PY'
import json, os, sys

path, name = sys.argv[1], sys.argv[2]

with open(path) as handle:
    config = json.load(handle)

servers = config.get('servers') or {}

key = next((k for k, s in servers.items() if s.get('name', k) == name), None)
if key is None:
    sys.stderr.write("Server '%s' not found\n" % name)
    sys.exit(1)

del servers[key]

# If the removed server was active, fall back to any remaining one.
if config.get('active') == key:
    config['active'] = next(iter(servers), '')

tmp = path + '.tmp'
with open(tmp, 'w') as handle:
    json.dump(config, handle, indent=2)
os.replace(tmp, path)
PY

if [ $? -ne 0 ]; then
    osascript -e "display alert \"Removal Failed\" message \"Could not remove '$SERVER_NAME'.\" as warning" 2>/dev/null
    exit 1
fi

csu_log "🗑️ Removed server $SERVER_NAME"
osascript -e "display notification \"Server removed: $SERVER_NAME\" with title \"Server Removed\"" 2>/dev/null

csu_restart_daemon
