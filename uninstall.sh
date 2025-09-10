#!/bin/bash

# Claude Screenshot Uploader - Uninstall Script
# This script will completely remove the screenshot uploader

echo "🗑️  Claude Screenshot Uploader Uninstall"
echo "========================================"
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

read -p "Are you sure you want to uninstall? (y/n) " -n 1 -r
echo ""
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Uninstall cancelled."
    exit 0
fi

echo ""
echo "Removing components..."

# Stop and unload LaunchAgent
PLIST_FILE="$HOME/Library/LaunchAgents/com.claudecode.screenshot-uploader.plist"
if [ -f "$PLIST_FILE" ]; then
    launchctl unload "$PLIST_FILE" 2>/dev/null || true
    rm "$PLIST_FILE"
    echo -e "${GREEN}✅ LaunchAgent removed${NC}"
fi

# Remove xbar plugin
XBAR_PLUGIN="$HOME/Library/Application Support/xbar/plugins/screenshot-uploader.1s.sh"
if [ -f "$XBAR_PLUGIN" ]; then
    rm "$XBAR_PLUGIN"
    echo -e "${GREEN}✅ xbar plugin removed${NC}"
fi

# Remove main script directory
SCRIPT_DIR="$HOME/claude-screenshot-uploader"
if [ -d "$SCRIPT_DIR" ]; then
    rm -rf "$SCRIPT_DIR"
    echo -e "${GREEN}✅ Script directory removed${NC}"
fi

# Ask about configuration file
CONFIG_FILE="$HOME/.claude-screenshot-uploader.conf"
if [ -f "$CONFIG_FILE" ]; then
    echo ""
    read -p "Remove configuration file? (y/n) " -n 1 -r
    echo ""
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        rm "$CONFIG_FILE"
        echo -e "${GREEN}✅ Configuration removed${NC}"
    else
        echo -e "${YELLOW}ℹ️  Configuration kept at $CONFIG_FILE${NC}"
    fi
fi

# Ask about log files
echo ""
read -p "Remove log files? (y/n) " -n 1 -r
echo ""
if [[ $REPLY =~ ^[Yy]$ ]]; then
    rm -f /tmp/screenshot-uploader.log
    rm -f /tmp/screenshot-uploader-error.log
    rm -f /tmp/screenshot-uploader-status
    echo -e "${GREEN}✅ Log files removed${NC}"
fi

# Ask about screenshot directory
echo ""
echo -e "${YELLOW}ℹ️  Your Screenshots directory at ~/Screenshots was not removed${NC}"
echo "   It may contain your screenshots"

# Reset screenshot location to Desktop if desired
echo ""
read -p "Reset screenshot location back to Desktop? (y/n) " -n 1 -r
echo ""
if [[ $REPLY =~ ^[Yy]$ ]]; then
    defaults delete com.apple.screencapture location 2>/dev/null || true
    killall SystemUIServer
    echo -e "${GREEN}✅ Screenshot location reset to Desktop${NC}"
fi

echo ""
echo "========================================="
echo -e "${GREEN}✅ Uninstall complete!${NC}"
echo ""
echo "Thank you for using Claude Screenshot Uploader!"
echo "Feel free to reinstall anytime from:"
echo "https://github.com/yourusername/claude-screenshot-uploader"