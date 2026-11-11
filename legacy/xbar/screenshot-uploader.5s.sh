#!/bin/bash

# Claude Screenshot Uploader — xbar plugin (manual upload mode)
#
# Menu bar control for uploading the newest screenshot to a configured server on
# demand, plus switching between servers. The auto-upload daemon modes are
# separate and optional; this plugin works with or without one running.
#
# Install to: ~/Library/Application Support/xbar/plugins/
# The 5s in the filename is xbar's refresh interval.

INSTALL_DIR="$HOME/claude-screenshot-uploader"
HELP_URL="https://github.com/mdrzn/claude-screenshot-uploader"

if [ ! -r "$INSTALL_DIR/helpers/common.sh" ]; then
    echo "📸 ⚠️"
    echo "---"
    echo "⚠️ Uploader not found at $INSTALL_DIR | color=red"
    echo "---"
    echo "📖 Setup instructions | href='$HELP_URL'"
    exit 0
fi

# shellcheck source=../helpers/common.sh
source "$INSTALL_DIR/helpers/common.sh"

VERSION="$(csu_version)"

if [ ! -f "$CSU_CONFIG_FILE" ]; then
    echo "📸 ⚠️"
    echo "---"
    echo "⚠️ Not Configured | color=orange"
    echo "---"
    echo "➕ Add First Server... | shell='$INSTALL_DIR/helpers/add-server.sh' terminal=false refresh=true"
    echo "---"
    echo "📖 Help | href='$HELP_URL'"
    echo "---"
    echo "v$VERSION | size=10 color=gray"
    exit 0
fi

# ── Read config (one python3 call) ────────────────────────────────────────────

CONFIG_ROWS="$(csu_config_dump)"

if [ -z "$CONFIG_ROWS" ] || printf '%s\n' "$CONFIG_ROWS" | grep -q '^ERROR'; then
    ERROR_MESSAGE="$(printf '%s\n' "$CONFIG_ROWS" | awk -F'\t' '/^ERROR/ {print $2; exit}')"
    echo "📸 ⚠️"
    echo "---"
    echo "⚠️ ${ERROR_MESSAGE:-Could not read configuration} | color=red"
    echo "--$CSU_CONFIG_FILE | size=10 color=gray"
    echo "---"
    echo "➕ Add Server... | shell='$INSTALL_DIR/helpers/add-server.sh' terminal=false refresh=true"
    echo "🔄 Refresh | refresh=true"
    echo "---"
    echo "v$VERSION | size=10 color=gray"
    exit 0
fi

SCREENSHOTS_DIR="$(printf '%s\n' "$CONFIG_ROWS" | awk -F'\t' '/^DIR/ {print $2; exit}')"
SERVER_ROWS="$(printf '%s\n' "$CONFIG_ROWS" | grep '^SERVER')"
SERVER_COUNT="$(printf '%s\n' "$CONFIG_ROWS" | grep -c '^SERVER')"

ACTIVE_ROW="$(printf '%s\n' "$CONFIG_ROWS" | grep '^ACTIVE' | head -n 1)"
if [ -n "$ACTIVE_ROW" ]; then
    IFS=$'\t' read -r _ ACTIVE_KEY ACTIVE_NAME ACTIVE_HOST ACTIVE_USER ACTIVE_PATH _ <<< "$ACTIVE_ROW"
else
    ACTIVE_KEY=""
fi

# ── Menu bar title ────────────────────────────────────────────────────────────

csu_clear_stale_status

if [ -f "$CSU_STATUS_FILE" ]; then
    IFS=':' read -r _ UPLOADING_FILE UPLOADING_SERVER < "$CSU_STATUS_FILE"
    ICON="📸 🔵"
    STATUS_TEXT="Uploading ${UPLOADING_FILE:-screenshot} to ${UPLOADING_SERVER:-server}..."
    STATUS_COLOR="blue"
elif [ -n "$ACTIVE_KEY" ]; then
    if [ ${#ACTIVE_HOST} -gt 15 ]; then
        SHORT_HOST="$(printf '%.12s...' "$ACTIVE_HOST")"
    else
        SHORT_HOST="$ACTIVE_HOST"
    fi
    ICON="📸 → $SHORT_HOST"
    STATUS_TEXT="Ready to upload"
    STATUS_COLOR="gray"
else
    ICON="📸"
    STATUS_TEXT="No server selected"
    STATUS_COLOR="orange"
fi

echo "$ICON"
echo "---"
echo "$STATUS_TEXT | size=11 color=$STATUS_COLOR"

# ── Update check ──────────────────────────────────────────────────────────────
#
# Only ever reads the cache. If it's stale, a detached refresh is fired whose
# result shows up on a later menu refresh — the network is never on this path.

UPDATE_AVAILABLE=""
UPDATE_LATEST=""

if [ -f "$CSU_UPDATE_CACHE" ]; then
    while IFS='=' read -r FIELD VALUE; do
        case "$FIELD" in
            latest) UPDATE_LATEST="$VALUE" ;;
            update) UPDATE_AVAILABLE="$VALUE" ;;
        esac
    done < "$CSU_UPDATE_CACHE"
fi

if [ ! -f "$CSU_UPDATE_CACHE" ] || [ "$(csu_file_age "$CSU_UPDATE_CACHE")" -gt 86400 ]; then
    # Fully detached: stdout and stderr are closed so xbar doesn't wait on the
    # inherited pipe, which would hang the menu until the check finished.
    ( "$INSTALL_DIR/helpers/check-update.sh" >/dev/null 2>&1 & ) &
fi

if [ "$UPDATE_AVAILABLE" = "yes" ] && [ -n "$UPDATE_LATEST" ]; then
    echo "---"
    echo "⬆️ Update available: v$UPDATE_LATEST | color=orange"
    echo "--⬇️ Update now | shell='$INSTALL_DIR/helpers/self-update.sh' terminal=true refresh=true"
    echo "--📝 What changed | href='$HELP_URL/releases'"
fi

echo "---"

# ── Newest screenshot ─────────────────────────────────────────────────────────

LATEST_SCREENSHOT="$(csu_latest_screenshot "$SCREENSHOTS_DIR")"

if [ -n "$LATEST_SCREENSHOT" ]; then
    echo "📸 Latest Screenshot:"
    echo "--$(basename "$LATEST_SCREENSHOT") | size=11"
    LATEST_TIME="$(stat -f "%Sm" -t "%b %d, %H:%M" "$LATEST_SCREENSHOT" 2>/dev/null)"
    [ -n "$LATEST_TIME" ] && echo "--$LATEST_TIME | size=10 color=gray"
    echo "--👁️ Preview | shell='open' param1='$LATEST_SCREENSHOT' terminal=false"
else
    echo "📸 No screenshots found | color=gray"
    echo "--$SCREENSHOTS_DIR | size=10 color=gray"
fi

echo "---"

# ── Upload actions ────────────────────────────────────────────────────────────

if [ -z "$LATEST_SCREENSHOT" ]; then
    echo "📤 Upload Latest Screenshot | disabled=true"
    echo "--Take a screenshot first | size=11 color=gray"
elif [ -z "$ACTIVE_KEY" ]; then
    echo "📤 Upload Latest Screenshot | disabled=true"
    echo "--⚠️ Select a server first | size=11 color=gray"
else
    echo "📤 Upload to $ACTIVE_NAME | shell='$INSTALL_DIR/helpers/upload-latest.sh' terminal=false refresh=true"
fi

if [ -n "$LATEST_SCREENSHOT" ] && [ "$SERVER_COUNT" -gt 1 ]; then
    echo "📤 Upload to..."
    printf '%s\n' "$SERVER_ROWS" | while IFS=$'\t' read -r _ KEY NAME HOST USER _ _; do
        [ -n "$KEY" ] || continue
        if [ "$KEY" = "$ACTIVE_KEY" ]; then
            echo "--✓ $NAME | shell='$INSTALL_DIR/helpers/upload-latest.sh' param1='$KEY' terminal=false refresh=true"
        else
            echo "--$NAME | shell='$INSTALL_DIR/helpers/upload-latest.sh' param1='$KEY' terminal=false refresh=true"
        fi
        echo "--$USER@$HOST | size=10 color=gray alternate=true"
    done
fi

echo "---"

# ── Active server ─────────────────────────────────────────────────────────────

if [ -n "$ACTIVE_KEY" ]; then
    echo "🖥️ Active Server: $ACTIVE_NAME | color=green"
    echo "--$ACTIVE_USER@$ACTIVE_HOST:$ACTIVE_PATH | size=11 color=gray"
else
    echo "🖥️ Active Server: None selected | color=orange"
fi

echo "---"

# ── Server selector ───────────────────────────────────────────────────────────

if [ "$SERVER_COUNT" -gt 0 ]; then
    echo "⚙️ Change Server:"
    printf '%s\n' "$SERVER_ROWS" | while IFS=$'\t' read -r _ KEY NAME HOST USER _ _; do
        [ -n "$KEY" ] || continue
        if [ "$KEY" = "$ACTIVE_KEY" ]; then
            echo "--✓ $NAME | shell='$INSTALL_DIR/helpers/switch-server.sh' param1='$KEY' terminal=false refresh=true"
        else
            echo "--◯ $NAME | shell='$INSTALL_DIR/helpers/switch-server.sh' param1='$KEY' terminal=false refresh=true"
        fi
        echo "--$USER@$HOST | size=10 color=gray alternate=true"
    done
else
    echo "⚠️ No servers configured | color=orange"
fi

echo "---"

# ── Upload mode ───────────────────────────────────────────────────────────────

ACTIVE_MODE="$(csu_active_mode)"

case "$ACTIVE_MODE" in
    manual)     MODE_LABEL="Manual — you click Upload" ;;
    polling)    MODE_LABEL="Polling — automatic, checks every 2s" ;;
    watchpaths) MODE_LABEL="WatchPaths — automatic, on folder change" ;;
    fswatch)    MODE_LABEL="fswatch — automatic, instant" ;;
    legacy)     MODE_LABEL="Pre-2.0 daemon — re-run setup.sh" ;;
    *)          MODE_LABEL="$ACTIVE_MODE" ;;
esac

if [ "$ACTIVE_MODE" = "manual" ]; then
    echo "⚡ Upload Mode: Manual | color=gray"
else
    echo "⚡ Upload Mode: $ACTIVE_MODE | color=green"
fi
echo "--$MODE_LABEL | size=11 color=gray"
echo "-----"
for MODE_OPTION in manual polling watchpaths fswatch; do
    case "$MODE_OPTION" in
        manual)     OPTION_TEXT="Manual — click to upload" ;;
        polling)    OPTION_TEXT="Polling — every 2 seconds" ;;
        watchpaths) OPTION_TEXT="WatchPaths — on folder change" ;;
        fswatch)    OPTION_TEXT="fswatch — instant (needs fswatch)" ;;
    esac
    if [ "$MODE_OPTION" = "$ACTIVE_MODE" ]; then
        echo "--✓ $OPTION_TEXT | shell='$INSTALL_DIR/helpers/set-mode.sh' param1='$MODE_OPTION' terminal=false refresh=true"
    else
        echo "--◯ $OPTION_TEXT | shell='$INSTALL_DIR/helpers/set-mode.sh' param1='$MODE_OPTION' terminal=false refresh=true"
    fi
done

echo "---"

echo "⚙️ Server Management:"
echo "--➕ Add New Server... | shell='$INSTALL_DIR/helpers/add-server.sh' terminal=false refresh=true"
if [ "$SERVER_COUNT" -gt 0 ]; then
    echo "--✏️ Edit Server... | shell='$INSTALL_DIR/helpers/edit-server.sh' terminal=false refresh=true"
    echo "--🗑️ Remove Server... | shell='$INSTALL_DIR/helpers/remove-server.sh' terminal=false refresh=true"
fi

# ── Recent activity ───────────────────────────────────────────────────────────

if [ -s "$CSU_LOG_FILE" ]; then
    # Only the tail is scanned — the log is append-only and grows without bound,
    # and this runs on every refresh.
    RECENT="$(tail -n 200 "$CSU_LOG_FILE" 2>/dev/null | grep -E '(✅|❌|📸)' | tail -n 5 | tail -r)"
    if [ -n "$RECENT" ]; then
        echo "---"
        echo "📊 Recent Activity:"
        printf '%s\n' "$RECENT" | while IFS= read -r LINE; do
            # Drop the timestamp when there is one. Lines written before 2.0 have
            # no stamp, and a blind prefix strip would eat their first two words.
            if [[ "$LINE" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}\ [0-9]{2}:[0-9]{2}:[0-9]{2}\ (.*)$ ]]; then
                echo "--${BASH_REMATCH[1]} | size=11"
            else
                echo "--$LINE | size=11"
            fi
        done
    fi
fi

echo "---"

echo "🛠️ Tools:"
echo "--📂 Open Screenshots Folder | shell='open' param1='$SCREENSHOTS_DIR' terminal=false"
if [ -n "$ACTIVE_KEY" ]; then
    echo "--🔐 Test SSH Connection | shell='ssh' param1='-o' param2='ConnectTimeout=5' param3='$ACTIVE_USER@$ACTIVE_HOST' param4='echo' param5='Connection successful!' terminal=true"
fi
if [ -f "$CSU_LOG_FILE" ]; then
    echo "--📋 View Logs | shell='tail' param1='-50' param2='$CSU_LOG_FILE' terminal=true"
fi

echo "---"
echo "📖 Documentation | href='$HELP_URL'"
echo "🔄 Refresh | refresh=true"
echo "---"
echo "v$VERSION · $ACTIVE_MODE mode | size=10 color=gray"
