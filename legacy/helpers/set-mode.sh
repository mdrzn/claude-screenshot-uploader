#!/bin/bash

# Switch the upload mode.
# Usage: set-mode.sh manual|polling|watchpaths|fswatch
#
# Exactly one mode is ever installed: any previously loaded agent is unloaded and
# removed first, so two daemons can't both upload the same screenshot. Manual mode
# is the absence of a daemon.

source "$(dirname "$0")/common.sh"

LAUNCH_AGENTS="$HOME/Library/LaunchAgents"
MODE="$1"

case "$MODE" in
    manual|polling|watchpaths|fswatch) ;;
    *)
        echo "Usage: $(basename "$0") manual|polling|watchpaths|fswatch" >&2
        exit 1
        ;;
esac

PREVIOUS="$(csu_active_mode)"

if [ "$MODE" = "$PREVIOUS" ]; then
    csu_notify "Upload Mode" "Already using $MODE mode"
    exit 0
fi

# fswatch is the only mode with an external dependency — check before tearing
# down the working setup, so a missing binary can't leave nothing installed.
if [ "$MODE" = "fswatch" ] && ! command -v fswatch > /dev/null 2>&1 && [ ! -x /opt/homebrew/bin/fswatch ]; then
    osascript -e 'display alert "fswatch Not Installed" message "fswatch mode needs it:\n\n    brew install fswatch\n\nThe upload mode was left unchanged." as warning' 2>/dev/null
    exit 1
fi

mkdir -p "$LAUNCH_AGENTS"

# Remove every installed mode, including the pre-2.0 unsuffixed label.
for PLIST in "$LAUNCH_AGENTS/$CSU_LABEL_PREFIX".plist "$LAUNCH_AGENTS/$CSU_LABEL_PREFIX".*.plist; do
    [ -f "$PLIST" ] || continue
    launchctl unload "$PLIST" 2>/dev/null || true
    rm -f "$PLIST"
done

if [ "$MODE" = "manual" ]; then
    csu_log "⚡ Upload mode → manual (no daemon)"
    csu_notify "Upload Mode" "Manual — click Upload in the menu" "No background daemon is running"
    exit 0
fi

SOURCE_PLIST="$CSU_ROOT/$CSU_LABEL_PREFIX.$MODE.plist"

if [ ! -f "$SOURCE_PLIST" ]; then
    csu_log "❌ Missing plist template for $MODE mode"
    osascript -e "display alert \"Could Not Switch\" message \"Missing template:\n$SOURCE_PLIST\" as warning" 2>/dev/null
    exit 1
fi

SCREENSHOTS_DIR="$(csu_config_dump 2>/dev/null | awk -F'\t' '/^DIR/ {print $2; exit}')"
SCREENSHOTS_DIR="${SCREENSHOTS_DIR:-$HOME/Screenshots}"
mkdir -p "$SCREENSHOTS_DIR"

TARGET_PLIST="$LAUNCH_AGENTS/$CSU_LABEL_PREFIX.$MODE.plist"

sed -e "s|__INSTALL_DIR__|$CSU_ROOT|g" \
    -e "s|__HOME__|$HOME|g" \
    -e "s|__SCREENSHOTS_DIR__|$SCREENSHOTS_DIR|g" \
    "$SOURCE_PLIST" > "$TARGET_PLIST"

if ! launchctl load "$TARGET_PLIST" 2>/dev/null; then
    rm -f "$TARGET_PLIST"
    csu_log "❌ launchctl refused to load $MODE mode"
    osascript -e "display alert \"Could Not Switch\" message \"launchctl would not load $MODE mode. Upload mode is now manual.\" as warning" 2>/dev/null
    exit 1
fi

csu_log "⚡ Upload mode → $MODE"
csu_notify "Upload Mode" "$MODE — uploads happen automatically" "Switched from $PREVIOUS"
