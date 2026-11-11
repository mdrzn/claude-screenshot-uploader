#!/bin/bash

# Add a server profile, prompting through native dialogs.

source "$(dirname "$0")/common.sh"

mkdir -p "$CSU_CONFIG_DIR"

# Convert a pre-2.0 shell config if one is still around.
if [ ! -f "$CSU_CONFIG_FILE" ] && [ -x "$CSU_ROOT/migrate-config.sh" ]; then
    "$CSU_ROOT/migrate-config.sh" > /dev/null 2>&1 || true
fi

if [ ! -f "$CSU_CONFIG_FILE" ]; then
    echo '{"active": "", "servers": {}, "local_screenshots": "'"$HOME"'/Screenshots"}' > "$CSU_CONFIG_FILE"
fi

ask() {
    # $1 prompt, $2 default, $3 window title
    osascript -e "display dialog \"$1\" default answer \"$2\" with title \"$3\" with icon note" \
        -e 'text returned of result' 2>/dev/null
}

SERVER_NAME="$(ask "Name for this server profile:" "My Server" "Add Server")"
[ -n "$SERVER_NAME" ] || { echo "Cancelled"; exit 0; }

SERVER_HOST="$(ask "Hostname or IP:" "example.com" "Add Server — Host")"
[ -n "$SERVER_HOST" ] || { echo "Cancelled"; exit 0; }

SERVER_USER="$(ask "SSH username:" "$USER" "Add Server — User")"
[ -n "$SERVER_USER" ] || { echo "Cancelled"; exit 0; }

SERVER_PATH="$(ask "Remote directory for screenshots:" "/tmp/screenshots" "Add Server — Path")"
[ -n "$SERVER_PATH" ] || { echo "Cancelled"; exit 0; }

AUTO_DELETE_ANSWER="$(osascript -e 'button returned of (display dialog "Delete local screenshots after a successful upload?" buttons {"Keep", "Delete"} default button "Keep" with title "Add Server — Options" with icon note)' 2>/dev/null)"
if [ "$AUTO_DELETE_ANSWER" = "Delete" ]; then
    AUTO_DELETE=1
else
    AUTO_DELETE=0
fi

# Values go through the environment, never into the Python source, so a quote or
# backslash in a server name can't break or rewrite the script.
CSU_CONFIG_FILE="$CSU_CONFIG_FILE" \
SERVER_NAME="$SERVER_NAME" SERVER_HOST="$SERVER_HOST" SERVER_USER="$SERVER_USER" \
SERVER_PATH="$SERVER_PATH" AUTO_DELETE="$AUTO_DELETE" \
python3 <<'PY'
import json, os, re, sys

path = os.environ['CSU_CONFIG_FILE']
name = os.environ['SERVER_NAME']

with open(path) as handle:
    config = json.load(handle)

config.setdefault('servers', {})

if any(s.get('name') == name for s in config['servers'].values()):
    sys.stderr.write('duplicate')
    sys.exit(2)

key = re.sub(r'[^a-z0-9]', '_', name.lower()) or 'server'
base = key
suffix = 2
while key in config['servers']:
    key = '%s_%d' % (base, suffix)
    suffix += 1

config['servers'][key] = {
    'name': name,
    'host': os.environ['SERVER_HOST'],
    'user': os.environ['SERVER_USER'],
    'path': os.environ['SERVER_PATH'],
    'auto_delete': os.environ['AUTO_DELETE'] == '1',
}

if not config.get('active'):
    config['active'] = key

tmp = path + '.tmp'
with open(tmp, 'w') as handle:
    json.dump(config, handle, indent=2)
os.replace(tmp, path)
PY

STATUS=$?

if [ $STATUS -eq 2 ]; then
    osascript -e "display alert \"Server Exists\" message \"A server named '$SERVER_NAME' is already configured.\" as warning" 2>/dev/null
    exit 1
elif [ $STATUS -ne 0 ]; then
    osascript -e "display alert \"Could Not Add Server\" message \"Failed to write $CSU_CONFIG_FILE.\" as warning" 2>/dev/null
    exit 1
fi

csu_log "➕ Added server $SERVER_NAME"

if ssh -o BatchMode=yes -o ConnectTimeout=5 "$SERVER_USER@$SERVER_HOST" exit 2>/dev/null; then
    csu_notify "Server Added" "$SERVER_NAME is ready" "SSH connection verified"
else
    osascript -e "display alert \"Server Added\" message \"'$SERVER_NAME' was saved, but SSH did not connect without a password.\n\nSet up key authentication with:\n    ssh-copy-id $SERVER_USER@$SERVER_HOST\" as warning" 2>/dev/null
fi

csu_restart_daemon
