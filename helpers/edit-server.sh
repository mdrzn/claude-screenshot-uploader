#!/bin/bash

# Edit an existing server profile.

source "$(dirname "$0")/common.sh"

CONFIG_ROWS="$(csu_config_dump)"
if [ -z "$CONFIG_ROWS" ] || printf '%s\n' "$CONFIG_ROWS" | grep -q '^ERROR'; then
    osascript -e 'display alert "No Servers" message "No servers are configured." as informational' 2>/dev/null
    exit 1
fi

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

CHOSEN=$(osascript \
    -e "choose from list {$LIST_ITEMS} with prompt \"Select server to edit:\" with title \"Edit Server\"" \
    -e 'result' 2>/dev/null)

if [ -z "$CHOSEN" ] || [ "$CHOSEN" = "false" ]; then
    echo "Cancelled"
    exit 0
fi

SERVER_ROW="$(printf '%s\n' "$CONFIG_ROWS" | awk -F'\t' -v want="$CHOSEN" \
    '$1 == "SERVER" && $3 == want {print; exit}')"

if [ -z "$SERVER_ROW" ]; then
    osascript -e "display alert \"Not Found\" message \"'$CHOSEN' is no longer in the configuration.\" as warning" 2>/dev/null
    exit 1
fi

IFS=$'\t' read -r _ SERVER_KEY CURRENT_NAME CURRENT_HOST CURRENT_USER CURRENT_PATH CURRENT_AUTO_DELETE <<< "$SERVER_ROW"

ask() {
    # $1 prompt, $2 default, $3 window title
    osascript -e "display dialog \"$1\" default answer \"$2\" with title \"$3\" with icon note" \
        -e 'text returned of result' 2>/dev/null
}

NEW_NAME="$(ask "Display name:" "$CURRENT_NAME" "Edit Server — Name")"
[ -n "$NEW_NAME" ] || { echo "Cancelled"; exit 0; }

NEW_HOST="$(ask "Hostname or IP:" "$CURRENT_HOST" "Edit Server — Host")"
[ -n "$NEW_HOST" ] || { echo "Cancelled"; exit 0; }

NEW_USER="$(ask "SSH username:" "$CURRENT_USER" "Edit Server — User")"
[ -n "$NEW_USER" ] || { echo "Cancelled"; exit 0; }

NEW_PATH="$(ask "Remote directory for screenshots:" "$CURRENT_PATH" "Edit Server — Path")"
[ -n "$NEW_PATH" ] || { echo "Cancelled"; exit 0; }

if [ "$CURRENT_AUTO_DELETE" = "true" ]; then
    DEFAULT_BUTTON="Delete"
else
    DEFAULT_BUTTON="Keep"
fi

AUTO_DELETE_ANSWER="$(osascript -e "button returned of (display dialog \"Delete local screenshots after a successful upload?\" buttons {\"Keep\", \"Delete\"} default button \"$DEFAULT_BUTTON\" with title \"Edit Server — Options\" with icon note)" 2>/dev/null)"
if [ "$AUTO_DELETE_ANSWER" = "Delete" ]; then
    AUTO_DELETE=1
else
    AUTO_DELETE=0
fi

CSU_CONFIG_FILE="$CSU_CONFIG_FILE" SERVER_KEY="$SERVER_KEY" \
SERVER_NAME="$NEW_NAME" SERVER_HOST="$NEW_HOST" SERVER_USER="$NEW_USER" \
SERVER_PATH="$NEW_PATH" AUTO_DELETE="$AUTO_DELETE" \
python3 <<'PY'
import json, os, sys

path = os.environ['CSU_CONFIG_FILE']
key = os.environ['SERVER_KEY']

with open(path) as handle:
    config = json.load(handle)

if key not in config.get('servers', {}):
    sys.exit(1)

config['servers'][key].update({
    'name': os.environ['SERVER_NAME'],
    'host': os.environ['SERVER_HOST'],
    'user': os.environ['SERVER_USER'],
    'path': os.environ['SERVER_PATH'],
    'auto_delete': os.environ['AUTO_DELETE'] == '1',
})

tmp = path + '.tmp'
with open(tmp, 'w') as handle:
    json.dump(config, handle, indent=2)
os.replace(tmp, path)
PY

if [ $? -ne 0 ]; then
    osascript -e "display alert \"Update Failed\" message \"Could not update '$CHOSEN'.\" as warning" 2>/dev/null
    exit 1
fi

csu_log "✏️ Updated server $NEW_NAME"
csu_notify "Server Updated" "$NEW_NAME saved"

csu_restart_daemon
