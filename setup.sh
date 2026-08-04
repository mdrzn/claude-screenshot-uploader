#!/bin/bash

# Claude Screenshot Uploader — installer.

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

INSTALL_DIR="$HOME/claude-screenshot-uploader"
CONFIG_DIR="$HOME/.claude-screenshot-uploader"
CONFIG_FILE="$CONFIG_DIR/config.json"
LAUNCH_AGENTS="$HOME/Library/LaunchAgents"
XBAR_PLUGINS="$HOME/Library/Application Support/xbar/plugins"
LABEL_PREFIX="com.claudecode.screenshot-uploader"
SOURCE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "📸 Claude Screenshot Uploader — Setup"
echo "====================================="
echo ""

if [[ "$OSTYPE" != "darwin"* ]]; then
    echo -e "${RED}❌ This tool only works on macOS${NC}"
    exit 1
fi

# ── Dependencies ──────────────────────────────────────────────────────────────

echo "📋 Checking dependencies..."

if ! command -v python3 &> /dev/null; then
    echo -e "${RED}❌ python3 is required (used to read the config)${NC}"
    echo "   Install the Xcode command line tools:  xcode-select --install"
    exit 1
fi
echo -e "${GREEN}✅ python3${NC}"

if ! command -v rsync &> /dev/null; then
    echo -e "${RED}❌ rsync is required${NC}"
    exit 1
fi
echo -e "${GREEN}✅ rsync${NC}"

if [ -d "/Applications/xbar.app" ]; then
    echo -e "${GREEN}✅ xbar${NC}"
    HAVE_XBAR=true
else
    echo -e "${YELLOW}ℹ️  xbar not found — it provides the menu bar icon${NC}"
    HAVE_XBAR=false
    read -p "   Install xbar now with Homebrew? (y/n) " -n 1 -r
    echo ""
    if [[ $REPLY =~ ^[Yy]$ ]] && command -v brew &> /dev/null; then
        brew install --cask xbar && HAVE_XBAR=true
    fi
fi

# ── Install files ─────────────────────────────────────────────────────────────

echo ""
echo "📁 Installing to $INSTALL_DIR..."

if [ "$SOURCE_DIR" != "$INSTALL_DIR" ]; then
    mkdir -p "$INSTALL_DIR"
    # -R over the contents, excluding version control metadata.
    (cd "$SOURCE_DIR" && tar --exclude='.git' -cf - .) | (cd "$INSTALL_DIR" && tar -xf -)
    echo -e "${GREEN}✅ Files copied${NC}"
else
    echo -e "${GREEN}✅ Already running from the install directory${NC}"
fi

chmod +x "$INSTALL_DIR"/uploader-*.sh "$INSTALL_DIR"/helpers/*.sh \
         "$INSTALL_DIR"/xbar/*.sh "$INSTALL_DIR"/setup.sh "$INSTALL_DIR"/uninstall.sh 2>/dev/null || true

# ── Configuration ─────────────────────────────────────────────────────────────

mkdir -p "$CONFIG_DIR"

if [ -f "$CONFIG_FILE" ]; then
    echo -e "${GREEN}✅ Existing configuration kept at $CONFIG_FILE${NC}"
else
    echo ""
    echo "⚙️  Configure your first server:"
    echo ""
    read -p "   Display name [My Server]: " server_name
    server_name=${server_name:-My Server}
    read -p "   Hostname or IP: " server_host
    read -p "   SSH username: " server_user
    read -p "   Remote directory [/tmp/screenshots]: " server_path
    server_path=${server_path:-/tmp/screenshots}
    read -p "   Local screenshots directory [$HOME/Screenshots]: " local_dir
    local_dir=${local_dir:-$HOME/Screenshots}

    if [ -z "$server_host" ] || [ -z "$server_user" ]; then
        echo -e "${RED}❌ Hostname and username are required${NC}"
        exit 1
    fi

    SERVER_NAME="$server_name" SERVER_HOST="$server_host" SERVER_USER="$server_user" \
    SERVER_PATH="$server_path" LOCAL_DIR="$local_dir" CONFIG_FILE="$CONFIG_FILE" \
    python3 <<'PY'
import json, os, re

name = os.environ['SERVER_NAME']
key = re.sub(r'[^a-z0-9]', '_', name.lower()) or 'server'

config = {
    'active': key,
    'local_screenshots': os.environ['LOCAL_DIR'],
    'servers': {
        key: {
            'name': name,
            'host': os.environ['SERVER_HOST'],
            'user': os.environ['SERVER_USER'],
            'path': os.environ['SERVER_PATH'],
            'auto_delete': False,
        }
    },
}

with open(os.environ['CONFIG_FILE'], 'w') as handle:
    json.dump(config, handle, indent=2)
PY
    echo -e "${GREEN}✅ Configuration written to $CONFIG_FILE${NC}"
fi

SCREENSHOTS_DIR="$(python3 -c "
import json, os
with open('$CONFIG_FILE') as f:
    print(os.path.expanduser(os.path.expandvars(json.load(f).get('local_screenshots') or '~/Screenshots')))
")"
mkdir -p "$SCREENSHOTS_DIR"

# ── SSH check ─────────────────────────────────────────────────────────────────

SSH_TARGET="$(python3 -c "
import json
with open('$CONFIG_FILE') as f:
    c = json.load(f)
s = c['servers'].get(c.get('active'), {})
print('%s@%s' % (s.get('user', ''), s.get('host', '')) if s else '')
")"

if [ -n "$SSH_TARGET" ] && [ "$SSH_TARGET" != "@" ]; then
    echo ""
    echo "🔐 Testing SSH to $SSH_TARGET..."
    if ssh -o BatchMode=yes -o ConnectTimeout=5 "$SSH_TARGET" exit 2>/dev/null; then
        echo -e "${GREEN}✅ SSH works${NC}"
    else
        echo -e "${YELLOW}⚠️  Could not connect without a password.${NC}"
        echo "   Set up key authentication with:  ssh-copy-id $SSH_TARGET"
    fi
fi

# ── Upload mode ───────────────────────────────────────────────────────────────

echo ""
echo "📤 How should screenshots be uploaded?"
echo ""
echo "   1) Manual      — click the menu bar icon to upload. No daemon. (recommended)"
echo "   2) Polling     — a daemon checks every couple of seconds. Most reliable auto mode."
echo "   3) WatchPaths  — launchd triggers on directory changes. No polling, coalesces bursts."
echo "   4) fswatch     — resident watcher, uploads instantly. Needs: brew install fswatch"
echo ""
read -p "   Choose [1]: " mode_choice
mode_choice=${mode_choice:-1}

case "$mode_choice" in
    2) MODE="polling" ;;
    3) MODE="watchpaths" ;;
    4) MODE="fswatch" ;;
    *) MODE="manual" ;;
esac

# Remove any previously installed mode, so two daemons can't both upload.
mkdir -p "$LAUNCH_AGENTS"
for existing in "$LAUNCH_AGENTS/$LABEL_PREFIX".*.plist; do
    [ -f "$existing" ] || continue
    launchctl unload "$existing" 2>/dev/null || true
    rm -f "$existing"
done
launchctl unload "$LAUNCH_AGENTS/$LABEL_PREFIX.plist" 2>/dev/null || true
rm -f "$LAUNCH_AGENTS/$LABEL_PREFIX.plist"

if [ "$MODE" = "manual" ]; then
    echo -e "${GREEN}✅ Manual mode — no background daemon installed${NC}"
else
    if [ "$MODE" = "fswatch" ] && ! command -v fswatch &> /dev/null && [ ! -x /opt/homebrew/bin/fswatch ]; then
        echo -e "${YELLOW}⚠️  fswatch not found. Installing...${NC}"
        brew install fswatch
    fi

    PLIST_SOURCE="$INSTALL_DIR/$LABEL_PREFIX.$MODE.plist"
    PLIST_TARGET="$LAUNCH_AGENTS/$LABEL_PREFIX.$MODE.plist"

    sed -e "s|__INSTALL_DIR__|$INSTALL_DIR|g" \
        -e "s|__HOME__|$HOME|g" \
        -e "s|__SCREENSHOTS_DIR__|$SCREENSHOTS_DIR|g" \
        "$PLIST_SOURCE" > "$PLIST_TARGET"

    launchctl load "$PLIST_TARGET"
    echo -e "${GREEN}✅ Installed the $MODE daemon${NC}"
fi

# ── xbar plugin ───────────────────────────────────────────────────────────────

if [ "$HAVE_XBAR" = true ]; then
    echo ""
    echo "📊 Installing xbar plugin..."
    mkdir -p "$XBAR_PLUGINS"
    find "$XBAR_PLUGINS" -maxdepth 1 -name 'screenshot-uploader*.sh' -delete 2>/dev/null || true
    PLUGIN="$(basename "$(ls "$INSTALL_DIR"/xbar/screenshot-uploader.*s.sh | head -n 1)")"
    cp "$INSTALL_DIR/xbar/$PLUGIN" "$XBAR_PLUGINS/$PLUGIN"
    chmod +x "$XBAR_PLUGINS/$PLUGIN"
    killall xbar 2>/dev/null || true
    sleep 1
    open -a xbar
    echo -e "${GREEN}✅ Installed $PLUGIN${NC}"
fi

# ── macOS screenshot location ─────────────────────────────────────────────────

CURRENT_LOCATION="$(defaults read com.apple.screencapture location 2>/dev/null || echo "")"
if [ "$CURRENT_LOCATION" != "$SCREENSHOTS_DIR" ]; then
    echo ""
    echo "📸 macOS currently saves screenshots to: ${CURRENT_LOCATION:-the Desktop}"
    read -p "   Point macOS at $SCREENSHOTS_DIR instead? (y/n) " -n 1 -r
    echo ""
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        defaults write com.apple.screencapture location "$SCREENSHOTS_DIR"
        killall SystemUIServer
        echo -e "${GREEN}✅ Screenshots will now save to $SCREENSHOTS_DIR${NC}"
    else
        echo -e "${YELLOW}ℹ️  Left unchanged — make sure your capture tool writes to $SCREENSHOTS_DIR${NC}"
    fi
fi

# Prime the version check so the menu doesn't have to wait a day for it.
"$INSTALL_DIR/helpers/check-update.sh" --force > /dev/null 2>&1 || true

echo ""
echo "========================================="
echo -e "${GREEN}✅ Done — v$(cat "$INSTALL_DIR/VERSION" 2>/dev/null || echo "?") installed${NC}"
echo ""
echo "  1. Take a screenshot"
if [ "$MODE" = "manual" ]; then
    echo "  2. Click 📸 in the menu bar → Upload"
else
    echo "  2. It uploads automatically"
fi
echo "  3. The remote path is on your clipboard — paste it into Claude Code"
echo ""
echo "  Logs:   tail -f /tmp/screenshot-uploader.log"
echo "  Config: $CONFIG_FILE"
echo ""
