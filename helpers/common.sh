#!/bin/bash

# Shared definitions for the Claude Screenshot Uploader.
# Source this file, don't execute it:  source "$(dirname "$0")/common.sh"

# Locate the install directory from this file's own path, and confirm the guess
# by looking for VERSION there. Without that check an empty BASH_SOURCE (which is
# what happens if this file is sourced from a non-bash shell) silently resolves
# to the parent of the current directory instead.
_csu_locate_root() {
    local candidate
    if [ -n "${BASH_SOURCE[0]:-}" ]; then
        candidate="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." 2>/dev/null && pwd)"
        if [ -n "$candidate" ] && [ -f "$candidate/VERSION" ]; then
            printf '%s' "$candidate"
            return 0
        fi
    fi
    printf '%s' "$HOME/claude-screenshot-uploader"
}

CSU_ROOT="$(_csu_locate_root)"

CSU_CONFIG_DIR="$HOME/.claude-screenshot-uploader"
CSU_CONFIG_FILE="$CSU_CONFIG_DIR/config.json"
CSU_STATUS_FILE="/tmp/screenshot-uploader-status"
CSU_LOG_FILE="/tmp/screenshot-uploader.log"
CSU_LABEL_PREFIX="com.claudecode.screenshot-uploader"

# Kept next to the config rather than in /tmp so the once-a-day version check
# survives a reboot instead of firing again on every login.
CSU_UPDATE_CACHE="$CSU_CONFIG_DIR/update-check"

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

csu_notify() {
    # $1 title, $2 message, $3 subtitle (optional)
    osascript -e "display notification \"$2\" with title \"$1\" subtitle \"${3:-}\"" 2>/dev/null
}

# Upload one file to one server. Every entry point — the xbar plugin's manual
# upload and all the auto-upload daemon modes — goes through here, so the status
# file, clipboard, logging and notification behave identically in each.
#
# Usage: csu_upload <file> <name> <host> <user> <remote_path> <auto_delete>
# Returns 0 on success.
csu_upload() {
    local file="$1" name="$2" host="$3" user="$4" remote_path="$5" auto_delete="$6"
    local filename output status

    filename="$(basename "$file")"

    if [ -z "$host" ] || [ -z "$user" ]; then
        csu_log "❌ Server '$name' is missing a host or user"
        csu_notify "Upload Failed" "Server '$name' is misconfigured" "Host or user is empty"
        return 1
    fi

    csu_log "📸 Uploading $filename → $name"
    echo "uploading:$filename:$name" > "$CSU_STATUS_FILE"

    # accept-new trusts a host's key on first contact and pins it afterwards, so
    # a key that later changes is reported instead of silently accepted.
    output=$(rsync -a -e "ssh -o BatchMode=yes -o ConnectTimeout=5 -o StrictHostKeyChecking=accept-new" \
        "$file" "$user@$host:$remote_path/" 2>&1)
    status=$?

    # Hold the status file briefly so a menu refresh can catch the upload.
    sleep 1
    rm -f "$CSU_STATUS_FILE"

    if [ $status -ne 0 ]; then
        csu_log "❌ Failed $filename → $name: $output"
        csu_notify "Upload Failed" "Could not upload to $name" "Check the SSH connection"
        return 1
    fi

    printf '%s' "$remote_path/$filename" | pbcopy
    csu_log "✅ Uploaded $filename → $name"
    csu_notify "Screenshot Uploaded" "Path copied: $filename" "To: $name"

    if [ "$auto_delete" = "true" ]; then
        rm -f "$file"
        csu_log "🗑️ Deleted local copy of $filename"
    fi

    return 0
}

# Labels of every loaded uploader agent. Each daemon mode installs under its own
# label, so whichever mode the user picked is the one that gets restarted.
csu_loaded_labels() {
    launchctl list 2>/dev/null | awk -v prefix="$CSU_LABEL_PREFIX" '
        index($3, prefix) == 1 { print $3 }'
}

# Which upload mode is in effect: the suffix of whichever LaunchAgent is loaded,
# or "manual" when none is — manual mode is precisely the absence of a daemon.
csu_active_mode() {
    local label suffix
    label="$(csu_loaded_labels | head -n 1)"

    if [ -z "$label" ]; then
        printf 'manual'
        return 0
    fi

    suffix="${label#"$CSU_LABEL_PREFIX"}"
    suffix="${suffix#.}"

    # A bare prefix with no suffix is a pre-2.0 agent, from before each mode got
    # its own label.
    printf '%s' "${suffix:-legacy}"
}

# Ask the running daemon to pick up a config change (a server switch or edit).
csu_restart_daemon() {
    local label
    while IFS= read -r label; do
        [ -n "$label" ] && launchctl stop "$label" 2>/dev/null
    done < <(csu_loaded_labels)
    return 0
}
