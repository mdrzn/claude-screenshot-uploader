#!/bin/bash

# Update the uploader in place, then reinstall the xbar plugin and restart the
# daemon so the running copies match what was just pulled.
#
# Run from the menu (terminal=true) so the output is visible.

source "$(dirname "$0")/common.sh"

GITHUB_REPO="mdrzn/claude-screenshot-uploader"
XBAR_PLUGINS="$HOME/Library/Application Support/xbar/plugins"

echo "🔄 Claude Screenshot Uploader — update"
echo "======================================"
echo "Installed at: $CSU_ROOT"
echo "Current version: $(csu_version)"
echo ""

if [ ! -d "$CSU_ROOT/.git" ]; then
    echo "⚠️  This copy wasn't installed as a git clone, so it can't update itself."
    echo ""
    echo "    To update, pull a fresh copy and re-run setup.sh:"
    echo "      git clone https://github.com/$GITHUB_REPO.git"
    echo "      cd claude-screenshot-uploader && ./setup.sh"
    echo ""
    open "https://github.com/$GITHUB_REPO/releases" 2>/dev/null
    exit 1
fi

echo "📥 Fetching..."
if ! git -C "$CSU_ROOT" fetch --tags --quiet; then
    echo "❌ Could not reach the remote. Check your network and try again."
    exit 1
fi

if ! git -C "$CSU_ROOT" diff --quiet || ! git -C "$CSU_ROOT" diff --cached --quiet; then
    echo "⚠️  You have uncommitted local changes:"
    git -C "$CSU_ROOT" status --short
    echo ""
    echo "    Commit or stash them first — refusing to overwrite your work."
    exit 1
fi

BEFORE="$(git -C "$CSU_ROOT" rev-parse HEAD)"

echo "⬇️  Pulling..."
if ! git -C "$CSU_ROOT" pull --ff-only --quiet; then
    echo "❌ Pull failed (the branch may have diverged from the remote)."
    echo "    Resolve it manually with: git -C \"$CSU_ROOT\" status"
    exit 1
fi

AFTER="$(git -C "$CSU_ROOT" rev-parse HEAD)"

if [ "$BEFORE" = "$AFTER" ]; then
    echo "✅ Already up to date (v$(csu_version))."
else
    echo "✅ Updated to v$(csu_version)"
    echo ""
    git -C "$CSU_ROOT" log --oneline "$BEFORE..$AFTER" | sed 's/^/    /'
fi

# Reinstall the xbar plugin, since the installed file is a copy of the one in
# the repo rather than a symlink.
PLUGIN_SOURCE="$(ls "$CSU_ROOT"/xbar/screenshot-uploader.*s.sh 2>/dev/null | head -n 1)"
if [ -n "$PLUGIN_SOURCE" ] && [ -d "$XBAR_PLUGINS" ]; then
    echo ""
    echo "📊 Reinstalling xbar plugin..."
    # Drop older copies first, in case the refresh interval in the name changed.
    find "$XBAR_PLUGINS" -maxdepth 1 -name 'screenshot-uploader.*s.sh' -delete 2>/dev/null
    cp "$PLUGIN_SOURCE" "$XBAR_PLUGINS/$(basename "$PLUGIN_SOURCE")"
    chmod +x "$XBAR_PLUGINS/$(basename "$PLUGIN_SOURCE")"
    echo "   Installed $(basename "$PLUGIN_SOURCE")"
fi

# Restart whichever daemon mode is loaded, if any.
LOADED="$(csu_loaded_labels)"
if [ -n "$LOADED" ]; then
    echo ""
    echo "🚀 Restarting daemon..."
    while IFS= read -r LABEL; do
        [ -n "$LABEL" ] || continue
        launchctl kickstart -k "gui/$(id -u)/$LABEL" 2>/dev/null && echo "   Restarted $LABEL"
    done <<< "$LOADED"
fi

# Refresh the cached version check so the menu stops advertising the update.
"$CSU_ROOT/helpers/check-update.sh" --force > /dev/null 2>&1

echo ""
echo "🔁 Restarting xbar..."
killall xbar 2>/dev/null && sleep 1
open -a xbar 2>/dev/null

echo ""
echo "Done. You can close this window."
