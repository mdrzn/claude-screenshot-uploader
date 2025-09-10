#!/bin/bash
# Claude Screenshot Uploader Configuration
# Copy this file to ~/.claude-screenshot-uploader.conf and edit the values

# Server Configuration
SERVER_HOST="your-server.com"           # Your server hostname or IP address
SERVER_USER="your-username"             # SSH username for the server
SERVER_PATH="/tmp/screenshots"          # Remote directory for screenshots

# Local Configuration  
LOCAL_SCREENSHOTS="$HOME/Screenshots"    # Local directory where screenshots are saved
                                        # To change macOS screenshot location:
                                        # defaults write com.apple.screencapture location ~/Screenshots
                                        # killall SystemUIServer

# Options
AUTO_DELETE="false"                     # Set to "true" to delete local screenshots after upload
                                        # Set to "false" to keep local copies

# Note: Make sure you have SSH key authentication set up:
# ssh-copy-id your-username@your-server.com