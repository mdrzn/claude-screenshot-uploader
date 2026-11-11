#!/bin/bash
#
# LEGACY single-server configuration format (1.x).
#
# Only uploader-fswatch-legacy.sh still reads this. Everything else uses
# ~/.claude-screenshot-uploader/config.json, which supports multiple servers and
# is managed from the menu bar.
#
# Already have a file in this format? Convert it:
#     ./migrate-config.sh
#
# Setting up fresh? Run ./setup.sh instead — you don't need this file.
#
# To use it anyway, copy to ~/.claude-screenshot-uploader.conf and edit:

SERVER_HOST="your-server.com"            # hostname or IP
SERVER_USER="your-username"              # SSH username
SERVER_PATH="/tmp/screenshots"           # remote directory to upload into

LOCAL_SCREENSHOTS="$HOME/Screenshots"    # folder to watch

AUTO_DELETE="false"                      # "true" deletes the local copy after upload

# Key authentication is required — uploads never prompt for a password:
#     ssh-copy-id your-username@your-server.com
