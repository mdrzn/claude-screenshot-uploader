#!/bin/bash

# Auto-upload daemon — WatchPaths mode.
#
# launchd runs this whenever the screenshots directory changes (WatchPaths in the
# plist). No polling and no extra dependency, so it is idle until something
# actually happens — but launchd coalesces rapid changes into a single trigger,
# so several screenshots taken in quick succession may yield one upload.

export PATH="/opt/homebrew/bin:$PATH"

source "$(dirname "$0")/helpers/common.sh"

LAST_UPLOADED_FILE="/tmp/screenshot-uploader-last-uploaded"

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

if [ -f "$LAST_UPLOADED_FILE" ] && [ "$FILENAME" = "$(cat "$LAST_UPLOADED_FILE" 2>/dev/null)" ]; then
    exit 0
fi

# launchd also fires this at load time, so skip anything that was already
# sitting in the directory rather than uploading it on every login.
[ "$(csu_file_age "$LATEST")" -gt 30 ] && exit 0

# Give the capture tool a moment to finish writing the file.
sleep 0.5

echo "$FILENAME" > "$LAST_UPLOADED_FILE"

csu_upload "$LATEST" "$NAME" "$HOST" "$USER" "$REMOTE_PATH" "$AUTO_DELETE"
