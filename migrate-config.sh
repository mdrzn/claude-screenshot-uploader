#!/bin/bash

# Convert a pre-2.0 shell config (~/.claude-screenshot-uploader.conf, one server)
# into the multi-server config.json, or create an empty config.json if there is
# nothing to convert. Safe to run repeatedly.

CONFIG_DIR="$HOME/.claude-screenshot-uploader"
OLD_CONFIG="$HOME/.claude-screenshot-uploader.conf"
NEW_CONFIG="$CONFIG_DIR/config.json"

mkdir -p "$CONFIG_DIR"

if [ -f "$NEW_CONFIG" ]; then
    echo "✅ Already using config.json"
    exit 0
fi

if [ -f "$OLD_CONFIG" ]; then
    echo "📦 Converting $OLD_CONFIG..."
    # shellcheck source=/dev/null
    source "$OLD_CONFIG"
else
    echo "📝 Creating an empty configuration..."
fi

# Built with json.dump rather than a heredoc, so a quote or backslash in any
# value can't produce a config.json that no longer parses.
NEW_CONFIG="$NEW_CONFIG" \
SERVER_HOST="${SERVER_HOST:-}" \
SERVER_USER="${SERVER_USER:-}" \
SERVER_PATH="${SERVER_PATH:-/tmp/screenshots}" \
LOCAL_SCREENSHOTS="${LOCAL_SCREENSHOTS:-$HOME/Screenshots}" \
AUTO_DELETE="${AUTO_DELETE:-false}" \
python3 <<'PY'
import json, os

host = os.environ['SERVER_HOST']
config = {
    'active': '',
    'servers': {},
    'local_screenshots': os.environ['LOCAL_SCREENSHOTS'],
}

if host:
    config['active'] = 'default'
    config['servers']['default'] = {
        'name': 'Default Server',
        'host': host,
        'user': os.environ['SERVER_USER'],
        'path': os.environ['SERVER_PATH'],
        'auto_delete': os.environ['AUTO_DELETE'].strip().lower() in ('1', 'true', 'yes'),
    }

with open(os.environ['NEW_CONFIG'], 'w') as handle:
    json.dump(config, handle, indent=2)
PY

if [ $? -ne 0 ]; then
    echo "❌ Could not write $NEW_CONFIG"
    exit 1
fi

echo "✅ Wrote $NEW_CONFIG"
[ -f "$OLD_CONFIG" ] && echo "   The old config was left in place at $OLD_CONFIG"
exit 0
