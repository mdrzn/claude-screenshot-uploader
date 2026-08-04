#!/bin/bash

# Migrate from old .conf format to new JSON format
# This script helps users upgrade to multi-server support

CONFIG_DIR="$HOME/.claude-screenshot-uploader"
OLD_CONFIG="$HOME/.claude-screenshot-uploader.conf"
NEW_CONFIG="$CONFIG_DIR/config.json"

# Create config directory
mkdir -p "$CONFIG_DIR"

# Check if already migrated
if [ -f "$NEW_CONFIG" ]; then
    echo "✅ Config already migrated to JSON format"
    exit 0
fi

# Check if old config exists
if [ -f "$OLD_CONFIG" ]; then
    echo "📦 Migrating existing configuration..."
    
    # Source old config
    source "$OLD_CONFIG"
    
    # Create JSON config with existing server as "default"
    cat > "$NEW_CONFIG" << EOF
{
  "active": "default",
  "servers": {
    "default": {
      "name": "Default Server",
      "host": "${SERVER_HOST:-your-server.com}",
      "user": "${SERVER_USER:-your-username}",
      "path": "${SERVER_PATH:-/tmp/screenshots}",
      "auto_delete": ${AUTO_DELETE:-false}
    }
  },
  "local_screenshots": "${LOCAL_SCREENSHOTS:-$HOME/Screenshots}"
}
EOF
    
    echo "✅ Configuration migrated successfully"
    echo "   Old config preserved at: $OLD_CONFIG"
    echo "   New config created at: $NEW_CONFIG"
else
    echo "📝 Creating new configuration..."
    
    # Create default JSON config
    cat > "$NEW_CONFIG" << 'EOF'
{
  "active": "",
  "servers": {},
  "local_screenshots": "$HOME/Screenshots"
}
EOF
    
    echo "✅ Created empty configuration at: $NEW_CONFIG"
    echo "   Use the menu bar icon to add servers"
fi