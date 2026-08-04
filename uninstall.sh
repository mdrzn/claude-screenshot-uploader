#!/bin/bash

# Claude Screenshot Uploader — uninstaller.

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

INSTALL_DIR="$HOME/claude-screenshot-uploader"
CONFIG_DIR="$HOME/.claude-screenshot-uploader"
LEGACY_CONFIG="$HOME/.claude-screenshot-uploader.conf"
LAUNCH_AGENTS="$HOME/Library/LaunchAgents"
XBAR_PLUGINS="$HOME/Library/Application Support/xbar/plugins"
LABEL_PREFIX="com.claudecode.screenshot-uploader"

echo "🗑️  Claude Screenshot Uploader — Uninstall"
echo "=========================================="
echo ""

read -p "Remove the uploader? (y/n) " -n 1 -r
echo ""
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Cancelled."
    exit 0
fi

echo ""

# LaunchAgents — every mode, plus the pre-2.0 unsuffixed label.
REMOVED_AGENT=false
for plist in "$LAUNCH_AGENTS/$LABEL_PREFIX".plist "$LAUNCH_AGENTS/$LABEL_PREFIX".*.plist; do
    [ -f "$plist" ] || continue
    launchctl unload "$plist" 2>/dev/null || true
    rm -f "$plist"
    echo -e "${GREEN}✅ Removed $(basename "$plist")${NC}"
    REMOVED_AGENT=true
done
[ "$REMOVED_AGENT" = false ] && echo -e "${YELLOW}ℹ️  No LaunchAgent was installed${NC}"

# xbar plugins — both the current and the legacy plugin, at any interval.
if [ -d "$XBAR_PLUGINS" ]; then
    if find "$XBAR_PLUGINS" -maxdepth 1 -name 'screenshot-uploader*.sh' -print -delete 2>/dev/null | grep -q .; then
        echo -e "${GREEN}✅ xbar plugin removed${NC}"
        killall xbar 2>/dev/null && sleep 1 && open -a xbar 2>/dev/null
    fi
fi

# Scripts
if [ -d "$INSTALL_DIR" ]; then
    read -p "Remove $INSTALL_DIR? (y/n) " -n 1 -r
    echo ""
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        rm -rf "$INSTALL_DIR"
        echo -e "${GREEN}✅ Scripts removed${NC}"
    else
        echo -e "${YELLOW}ℹ️  Kept $INSTALL_DIR${NC}"
    fi
fi

# Configuration
if [ -d "$CONFIG_DIR" ] || [ -f "$LEGACY_CONFIG" ]; then
    echo ""
    read -p "Remove your server configuration? (y/n) " -n 1 -r
    echo ""
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        rm -rf "$CONFIG_DIR" "$LEGACY_CONFIG"
        echo -e "${GREEN}✅ Configuration removed${NC}"
    else
        echo -e "${YELLOW}ℹ️  Configuration kept at $CONFIG_DIR${NC}"
    fi
fi

# Runtime files
rm -f /tmp/screenshot-uploader.log \
      /tmp/screenshot-uploader-error.log \
      /tmp/screenshot-uploader-status \
      /tmp/screenshot-uploader-server \
      /tmp/screenshot-uploader-last-uploaded \
      /tmp/screenshot-uploader-last \
      /tmp/screenshot-uploader-debug.log
echo -e "${GREEN}✅ Logs and temporary files removed${NC}"

echo ""
echo -e "${YELLOW}ℹ️  Your screenshots were left untouched${NC}"

if [ -n "$(defaults read com.apple.screencapture location 2>/dev/null)" ]; then
    echo ""
    read -p "Reset the macOS screenshot location to the Desktop? (y/n) " -n 1 -r
    echo ""
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        defaults delete com.apple.screencapture location 2>/dev/null || true
        killall SystemUIServer
        echo -e "${GREEN}✅ Reset to Desktop${NC}"
    fi
fi

echo ""
echo -e "${GREEN}✅ Uninstall complete${NC}"
