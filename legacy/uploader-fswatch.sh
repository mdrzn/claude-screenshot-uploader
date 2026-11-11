#!/bin/bash

# Auto-upload daemon — fswatch mode.
#
# Stays resident and reacts to filesystem events, so uploads start the moment a
# screenshot lands. Requires fswatch (brew install fswatch), and depends on a
# long-lived process staying healthy.

export PATH="/opt/homebrew/bin:$PATH"

source "$(dirname "$0")/helpers/common.sh"

FSWATCH="$(command -v fswatch || echo /opt/homebrew/bin/fswatch)"

if [ ! -x "$FSWATCH" ]; then
    csu_log "❌ fswatch not found — install it with: brew install fswatch"
    exit 1
fi

if [ ! -f "$CSU_CONFIG_FILE" ]; then
    csu_log "❌ No configuration found. Add a server from the menu bar first."
    exit 1
fi

SCREENSHOTS_DIR="$(csu_config_dump 2>/dev/null | awk -F'\t' '/^DIR/ {print $2; exit}')"

if [ -z "$SCREENSHOTS_DIR" ] || [ ! -d "$SCREENSHOTS_DIR" ]; then
    csu_log "❌ Screenshots directory not found: ${SCREENSHOTS_DIR:-<unset>}"
    exit 1
fi

csu_log "🚀 Watching $SCREENSHOTS_DIR (fswatch mode)"

"$FSWATCH" -0 --event Created --event Updated --event MovedTo "$SCREENSHOTS_DIR" 2>/dev/null |
while read -r -d "" EVENT; do
    case "${EVENT##*.}" in
        png|PNG|jpg|JPG|jpeg|JPEG) ;;
        *) continue ;;
    esac

    [ -f "$EVENT" ] || continue

    # Re-read the config on every event so switching servers from the menu takes
    # effect without restarting the daemon.
    CONFIG_ROWS="$(csu_config_dump 2>/dev/null)" || continue
    printf '%s\n' "$CONFIG_ROWS" | grep -q '^ERROR' && continue

    ACTIVE_ROW="$(printf '%s\n' "$CONFIG_ROWS" | grep '^ACTIVE' | head -n 1)"
    [ -n "$ACTIVE_ROW" ] || continue

    IFS=$'\t' read -r _ KEY NAME HOST USER REMOTE_PATH AUTO_DELETE <<< "$ACTIVE_ROW"

    # Give the capture tool a moment to finish writing the file.
    sleep 0.5

    csu_upload "$EVENT" "$NAME" "$HOST" "$USER" "$REMOTE_PATH" "$AUTO_DELETE"
done
