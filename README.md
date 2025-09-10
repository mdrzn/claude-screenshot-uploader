# Claude Screenshot Uploader 📸

Automatically upload macOS screenshots to remote servers for seamless Claude Code integration. Perfect for when you're running Claude Code on a remote server via SSH and need to share screenshots from your local Mac.

![Status](https://img.shields.io/badge/status-active-success.svg)
![Platform](https://img.shields.io/badge/platform-macOS-blue.svg)
![License](https://img.shields.io/badge/license-MIT-green.svg)

## 🎯 Problem Solved

When using Claude Code on a remote server via SSH, you can't directly paste local images. This tool automatically:
1. Detects new screenshots on your Mac
2. Uploads them to your server via SSH
3. Copies the server path to your clipboard
4. Allows you to paste the path in Claude Code to view the image

## ✨ Features

- 🚀 **Automatic Detection** - Monitors for new screenshots in real-time
- 📋 **Clipboard Integration** - Server path instantly copied, ready to paste
- 🟢🟡🔴 **Visual Status** - Menu bar icon shows upload status (via xbar)
- 🔒 **Secure Transfer** - Uses SSH with key authentication
- ⚡ **Fast & Efficient** - Uses rsync for smart transfers
- 🎯 **Zero Interaction** - Completely automatic workflow
- 🗑️ **Optional Auto-Delete** - Can remove local files after upload

## 📋 Requirements

- macOS (tested on macOS 13+)
- SSH access to a remote server
- Homebrew (for installing dependencies)
- xbar (optional, for menu bar status)

## 🚀 Quick Install

```bash
# Clone the repository
git clone https://github.com/mdrzn/claude-screenshot-uploader.git
cd claude-screenshot-uploader

# Run the setup script
./setup.sh
```

The setup script will:
- Install required dependencies (fswatch)
- Configure your server settings
- Set up SSH keys if needed
- Install the background service
- Configure screenshot save location
- Install xbar plugin (if xbar is installed)

## ⚙️ Manual Installation

<details>
<summary>Click to expand manual installation steps</summary>

1. **Install dependencies:**
   ```bash
   brew install fswatch
   brew install --cask xbar  # Optional
   ```

2. **Clone and configure:**
   ```bash
   git clone https://github.com/mdrzn/claude-screenshot-uploader.git
   cd claude-screenshot-uploader
   
   # Create config from template
   cp config.example.sh ~/.claude-screenshot-uploader.conf
   # Edit the config with your server details
   open ~/.claude-screenshot-uploader.conf
   ```

3. **Install the service:**
   ```bash
   # Copy files
   cp -r . ~/claude-screenshot-uploader/
   cp com.claudecode.screenshot-uploader.plist ~/Library/LaunchAgents/
   
   # Start the service
   launchctl load ~/Library/LaunchAgents/com.claudecode.screenshot-uploader.plist
   ```

4. **Configure screenshot location:**
   ```bash
   defaults write com.apple.screencapture location ~/Screenshots
   killall SystemUIServer
   ```

5. **Install xbar plugin (optional):**
   ```bash
   cp xbar/screenshot-uploader.1s.sh ~/Library/Application\ Support/xbar/plugins/
   # Restart xbar
   ```

</details>

## 🔧 Configuration

Edit `~/.claude-screenshot-uploader.conf`:

```bash
# Server settings
SERVER_HOST="your-server.com"     # Your server hostname/IP
SERVER_USER="username"             # SSH username
SERVER_PATH="/tmp/screenshots"     # Remote directory

# Local settings
LOCAL_SCREENSHOTS="$HOME/Screenshots"  # Where screenshots are saved

# Options
AUTO_DELETE="false"                # Delete local files after upload
```

## 📸 Usage

1. **Take a screenshot** using macOS shortcuts:
   - `Cmd + Shift + 4` - Select area
   - `Cmd + Shift + 3` - Full screen
   - `Cmd + Shift + 5` - Screenshot tools

2. **Automatic upload** happens instantly:
   - xbar icon turns 🟡 during upload
   - Returns to 🟢 when complete

3. **Paste in Claude Code**:
   - The server path is already in your clipboard
   - Just paste it in Claude Code to reference the image

Example:
```
You: Can you look at this screenshot?
You: /tmp/screenshots/SCR-20250910-abcd.png
Claude: [Views and analyzes the image]
```

## 🎛️ Service Control

**Start service:**
```bash
launchctl load ~/Library/LaunchAgents/com.claudecode.screenshot-uploader.plist
```

**Stop service:**
```bash
launchctl unload ~/Library/LaunchAgents/com.claudecode.screenshot-uploader.plist
```

**View logs:**
```bash
tail -f /tmp/screenshot-uploader.log
```

**Check status via xbar:**
- Click the 📸 icon in your menu bar
- Shows current status and recent uploads

## 🔒 SSH Key Setup

For passwordless uploads, set up SSH keys:

```bash
# Generate SSH key (if you don't have one)
ssh-keygen -t rsa -b 4096

# Copy to server
ssh-copy-id username@your-server.com

# Test connection
ssh username@your-server.com
```

## 🗑️ Uninstall

To completely remove the uploader:

```bash
./uninstall.sh
```

This will:
- Stop and remove the background service
- Remove xbar plugin
- Optionally remove configuration and logs
- Reset screenshot location to Desktop

## 🐛 Troubleshooting

<details>
<summary>Screenshots not uploading</summary>

1. Check if service is running:
   ```bash
   launchctl list | grep screenshot
   ```

2. Check logs for errors:
   ```bash
   tail -30 /tmp/screenshot-uploader-error.log
   ```

3. Test SSH connection:
   ```bash
   ssh username@server "echo 'Connection OK'"
   ```

4. Verify fswatch is installed:
   ```bash
   which fswatch
   ```
</details>

<details>
<summary>Permission errors</summary>

If you see "Operation not permitted":
1. Go to System Settings → Privacy & Security → Files and Folders
2. Ensure Terminal has access to your Screenshots folder
3. Or use a different screenshot location (like ~/Screenshots)
</details>

<details>
<summary>xbar icon not showing</summary>

1. Ensure xbar is running
2. Refresh xbar plugins (Cmd+R in xbar menu)
3. Check plugin is executable:
   ```bash
   chmod +x ~/Library/Application\ Support/xbar/plugins/screenshot-uploader.1s.sh
   ```
</details>

## 📝 How It Works

1. **File Monitoring**: Uses `fswatch` to monitor the Screenshots directory for new files matching the pattern `SCR-*.png`

2. **Automatic Upload**: When a new screenshot is detected, it's immediately uploaded via `rsync` over SSH

3. **Clipboard Integration**: The remote file path is copied to clipboard using `pbcopy`

4. **Status Indication**: An xbar plugin shows real-time status in the menu bar

5. **Background Service**: Runs as a launchd service, starts automatically on login

## 🤝 Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

- Built for [Claude Code](https://claude.ai/code) users
- Uses [fswatch](https://github.com/emcrisostomo/fswatch) for file monitoring
- Menu bar integration via [xbar](https://xbarapp.com/)

## 📬 Support

If you encounter any issues or have questions:
- Open an [issue](https://github.com/yourusername/claude-screenshot-uploader/issues)
- Check existing [discussions](https://github.com/yourusername/claude-screenshot-uploader/discussions)

---

Made with ❤️ for the Claude Code community
