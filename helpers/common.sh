#!/bin/bash

# Shared definitions for the Claude Screenshot Uploader.
# Source this file, don't execute it:  source "$(dirname "$0")/common.sh"

CSU_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

CSU_CONFIG_DIR="$HOME/.claude-screenshot-uploader"
CSU_CONFIG_FILE="$CSU_CONFIG_DIR/config.json"
CSU_STATUS_FILE="/tmp/screenshot-uploader-status"
CSU_LOG_FILE="/tmp/screenshot-uploader.log"
CSU_LABEL_PREFIX="com.claudecode.screenshot-uploader"

# A status file older than this many seconds is assumed to be a leftover from an
# upload that was killed mid-flight, and is ignored rather than shown forever.
CSU_STATUS_MAX_AGE=60

csu_version() {
    if [ -f "$CSU_ROOT/VERSION" ]; then
        tr -d '[:space:]' < "$CSU_ROOT/VERSION"
    else
        printf 'unknown'
    fi
}

csu_log() {
    printf '%s %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*" >> "$CSU_LOG_FILE"
}

# Dump the config as tab-separated rows, so callers parse it with one python3
# call instead of one per field. Emits, in order:
#   DIR   <screenshots directory>
#   ACTIVE <key> <name> <host> <user> <path> <auto_delete>   (only if one is set)
#   SERVER <key> <name> <host> <user> <path> <auto_delete>   (one per server)
# On failure emits a single "ERROR <message>" row and returns non-zero.
csu_config_dump() {
    python3 - "$CSU_CONFIG_FILE" <<'PY'
import json, os, sys

path = sys.argv[1]

def clean(value):
    # Tabs and newlines are the row/field separators, so they can never appear
    # inside a value (server names are free-form user input).
    return str(value).replace('\t', ' ').replace('\n', ' ').strip()

try:
    with open(path) as handle:
        config = json.load(handle)
except FileNotFoundError:
    print('ERROR\tNo configuration file')
    sys.exit(1)
except (OSError, ValueError) as exc:
    print('ERROR\tUnreadable config: %s' % exc)
    sys.exit(1)

if not isinstance(config, dict):
    print('ERROR\tConfig is not a JSON object')
    sys.exit(1)

servers = config.get('servers') or {}
active = config.get('active') or ''

screenshots = config.get('local_screenshots') or '$HOME/Screenshots'
print('DIR\t%s' % clean(os.path.expanduser(os.path.expandvars(screenshots))))

def row(tag, key):
    server = servers[key]
    return '\t'.join([
        tag,
        clean(key),
        clean(server.get('name', key)),
        clean(server.get('host', '')),
        clean(server.get('user', '')),
        clean(server.get('path', '')),
        'true' if server.get('auto_delete') else 'false',
    ])

if active and active in servers:
    print(row('ACTIVE', active))

for key in servers:
    print(row('SERVER', key))
PY
}

# Print the newest screenshot in $1, or nothing if the directory has none.
#
# Sorting on the mtime that stat reports keeps this correct no matter how many
# files accumulate: piping thousands of names into `ls -t` lets xargs split the
# list into several invocations, each sorted separately, so the first batch's
# newest file wins instead of the real one.
csu_latest_screenshot() {
    local dir="$1"

    [ -n "$dir" ] && [ -d "$dir" ] || return 0

    find "$dir" -maxdepth 1 -type f \
        \( -iname '*.png' -o -iname '*.jpg' -o -iname '*.jpeg' \) \
        -exec stat -f '%m%t%N' {} + 2>/dev/null \
        | sort -rn \
        | head -n 1 \
        | cut -f2-
}

# Age in seconds of the file named by $1 (a huge number if it doesn't exist, so
# callers can compare against a threshold without a separate existence check).
csu_file_age() {
    local mtime
    mtime=$(stat -f %m "$1" 2>/dev/null) || { printf '999999'; return 0; }
    printf '%s' "$(( $(date +%s) - mtime ))"
}

# Remove a status file left behind by an upload that never finished, so the menu
# bar doesn't sit on the "uploading" icon indefinitely.
csu_clear_stale_status() {
    if [ -f "$CSU_STATUS_FILE" ] && [ "$(csu_file_age "$CSU_STATUS_FILE")" -gt "$CSU_STATUS_MAX_AGE" ]; then
        rm -f "$CSU_STATUS_FILE"
    fi
}

# Labels of every loaded uploader agent. Each daemon mode installs under its own
# label, so whichever mode the user picked is the one that gets restarted.
csu_loaded_labels() {
    launchctl list 2>/dev/null | awk -v prefix="$CSU_LABEL_PREFIX" '
        index($3, prefix) == 1 { print $3 }'
}

# Ask the running daemon to pick up a config change (a server switch or edit).
csu_restart_daemon() {
    local label
    while IFS= read -r label; do
        [ -n "$label" ] && launchctl stop "$label" 2>/dev/null
    done < <(csu_loaded_labels)
    return 0
}
