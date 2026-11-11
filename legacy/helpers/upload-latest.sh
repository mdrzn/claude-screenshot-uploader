#!/bin/bash

# Upload the newest screenshot to a server.
# Usage: upload-latest.sh [server_key]    (defaults to the active server)

source "$(dirname "$0")/common.sh"

CONFIG_ROWS="$(csu_config_dump)"
if [ -z "$CONFIG_ROWS" ] || printf '%s\n' "$CONFIG_ROWS" | grep -q '^ERROR'; then
    MESSAGE="$(printf '%s\n' "$CONFIG_ROWS" | awk -F'\t' '/^ERROR/ {print $2; exit}')"
    csu_log "❌ ${MESSAGE:-Could not read configuration}"
    csu_notify "Upload Failed" "${MESSAGE:-Could not read configuration}"
    exit 1
fi

SCREENSHOTS_DIR="$(printf '%s\n' "$CONFIG_ROWS" | awk -F'\t' '/^DIR/ {print $2; exit}')"

# Use the requested server, or fall back to the active one.
REQUESTED_KEY="$1"
if [ -n "$REQUESTED_KEY" ]; then
    SERVER_ROW="$(printf '%s\n' "$CONFIG_ROWS" | awk -F'\t' -v key="$REQUESTED_KEY" \
        '$1 == "SERVER" && $2 == key {print; exit}')"
    if [ -z "$SERVER_ROW" ]; then
        csu_log "❌ Server '$REQUESTED_KEY' not found in config"
        csu_notify "Upload Failed" "Server '$REQUESTED_KEY' not found"
        exit 1
    fi
else
    SERVER_ROW="$(printf '%s\n' "$CONFIG_ROWS" | grep '^ACTIVE' | head -n 1)"
    if [ -z "$SERVER_ROW" ]; then
        csu_log "❌ No active server selected"
        csu_notify "Upload Failed" "No server selected" "Select a server first"
        exit 1
    fi
fi

IFS=$'\t' read -r _ SERVER_KEY SERVER_NAME SERVER_HOST SERVER_USER SERVER_PATH AUTO_DELETE <<< "$SERVER_ROW"

LATEST_SCREENSHOT="$(csu_latest_screenshot "$SCREENSHOTS_DIR")"
if [ -z "$LATEST_SCREENSHOT" ]; then
    csu_log "❌ No screenshots found in $SCREENSHOTS_DIR"
    csu_notify "Upload Failed" "No screenshots in $SCREENSHOTS_DIR" "Take a screenshot first"
    exit 1
fi

csu_upload "$LATEST_SCREENSHOT" "$SERVER_NAME" "$SERVER_HOST" "$SERVER_USER" \
    "$SERVER_PATH" "$AUTO_DELETE"
