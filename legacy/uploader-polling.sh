#!/bin/bash

# Auto-upload daemon — polling mode.
#
# launchd runs this once per interval (StartInterval in the plist) and it exits
# immediately. Nothing stays resident, which makes it the most reliable mode: it
# has no file-watching API to lose track of, and it recovers on the next tick
# from anything that goes wrong.
#
# Trade-off: a screenshot is uploaded up to one interval after it is taken.

export PATH="/opt/homebrew/bin:$PATH"

source "$(dirname "$0")/helpers/common.sh"

LAST_UPLOADED_FILE="/tmp/screenshot-uploader-last-uploaded"

# Ignore anything older than this. Without it, restarting the daemon would
# re-upload whatever screenshot happens to be newest at the time.
MAX_SCREENSHOT_AGE=10

[ -f "$CSU_CONFIG_FILE" ] || exit 0

CONFIG_ROWS="$(csu_config_dump 2>/dev/null)" || exit 0
printf '%s\n' "$CONFIG_ROWS" | grep -q '^ERROR' && exit 0

ACTIVE_ROW="$(printf '%s\n' "$CONFIG_ROWS" | grep '^ACTIVE' | head -n 1)"
[ -n "$ACTIVE_ROW" ] || exit 0

IFS=$'\t' read -r _ KEY NAME HOST USER REMOTE_PATH AUTO_DELETE <<< "$ACTIVE_ROW"
SCREENSHOTS_DIR="$(printf '%s\n' "$CONFIG_ROWS" | awk -F'\t' '/^DIR/ {print $2; exit}')"

LATEST="$(csu_latest_screenshot "$SCREENSHOTS_DIR")"
[ -n "$LATEST" ] || exit 0

FILENAME="$(basename "$LATEST")"

# Already handled on an earlier tick.
if [ -f "$LAST_UPLOADED_FILE" ] && [ "$FILENAME" = "$(cat "$LAST_UPLOADED_FILE" 2>/dev/null)" ]; then
    exit 0
fi

[ "$(csu_file_age "$LATEST")" -gt "$MAX_SCREENSHOT_AGE" ] && exit 0

# Record it before uploading, so a slow or failing upload can't make every
# subsequent tick retry the same file.
echo "$FILENAME" > "$LAST_UPLOADED_FILE"

csu_upload "$LATEST" "$NAME" "$HOST" "$USER" "$REMOTE_PATH" "$AUTO_DELETE"
