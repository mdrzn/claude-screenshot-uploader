#!/bin/bash

# Auto-upload daemon — fswatch mode, single server, legacy shell config.
#
# Reads the original ~/.claude-screenshot-uploader.conf format and uploads to one
# fixed server. Kept for installs that predate multi-server support; new installs
# should use uploader-fswatch.sh, which reads config.json and can switch servers
# from the menu bar. Run helpers/../migrate-config.sh to convert.

export PATH="/opt/homebrew/bin:$PATH"

source "$(dirname "$0")/helpers/common.sh"

LEGACY_CONFIG="$HOME/.claude-screenshot-uploader.conf"

if [ ! -f "$LEGACY_CONFIG" ]; then
    echo "❌ Configuration file not found: $LEGACY_CONFIG"
    echo "   Create it from config.example.sh, or switch to uploader-fswatch.sh."
    exit 1
fi

# shellcheck source=/dev/null
source "$LEGACY_CONFIG"

: "${SERVER_HOST:=your-server.com}"
: "${SERVER_USER:=your-username}"
: "${SERVER_PATH:=/tmp/screenshots}"
: "${LOCAL_SCREENSHOTS:=$HOME/Screenshots}"
: "${AUTO_DELETE:=false}"

if [ "$SERVER_HOST" = "your-server.com" ]; then
    echo "❌ Set SERVER_HOST in $LEGACY_CONFIG"
    exit 1
fi

FSWATCH="$(command -v fswatch || echo /opt/homebrew/bin/fswatch)"

if [ ! -x "$FSWATCH" ]; then
    echo "❌ fswatch not found — install it with: brew install fswatch"
    exit 1
fi

echo "🔄 Checking remote directory..."
if ssh -o BatchMode=yes -o ConnectTimeout=5 "$SERVER_USER@$SERVER_HOST" \
        "mkdir -p '$SERVER_PATH' && chmod 755 '$SERVER_PATH'" 2>/dev/null; then
    echo "✅ Remote directory ready: $SERVER_PATH"
else
    echo "⚠️  Could not verify remote directory (an SSH key may be required)"
fi

echo ""
echo "🚀 Claude Screenshot Uploader started (fswatch, legacy config)"
echo "📁 Monitoring:  $LOCAL_SCREENSHOTS"
echo "📤 Uploading to: $SERVER_USER@$SERVER_HOST:$SERVER_PATH"
echo "🗑️  Auto-delete: $AUTO_DELETE"
echo "⏹️  Press Ctrl+C to stop"
echo ""

"$FSWATCH" -0 --event Created --event Updated --event MovedTo "$LOCAL_SCREENSHOTS" 2>/dev/null |
while read -r -d "" EVENT; do
    case "${EVENT##*.}" in
        png|PNG|jpg|JPG|jpeg|JPEG) ;;
        *) continue ;;
    esac

    [ -f "$EVENT" ] || continue

    sleep 0.5

    csu_upload "$EVENT" "$SERVER_HOST" "$SERVER_HOST" "$SERVER_USER" \
        "$SERVER_PATH" "$AUTO_DELETE"
done
