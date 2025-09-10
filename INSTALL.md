# Installation Guide

This guide provides detailed installation instructions for the Claude Screenshot Uploader.

## Prerequisites

- macOS 10.15 (Catalina) or later
- SSH access to a remote server
- Admin privileges on your Mac

## Option 1: Automated Installation (Recommended)

### Step 1: Download and Setup
```bash
# Clone the repository
git clone https://github.com/yourusername/claude-screenshot-uploader.git
cd claude-screenshot-uploader

# Make setup script executable (if needed)
chmod +x setup.sh

# Run the setup
./setup.sh
```

The setup script will guide you through:
- Installing Homebrew (if not installed)
- Installing fswatch dependency
- Installing xbar (optional)
- Configuring your server settings
- Setting up SSH keys
- Installing the background service

### Step 2: Test the Installation

1. Take a screenshot (`Cmd + Shift + 4`)
2. Check if the file appears in `~/Screenshots/`
3. Verify it uploads to your server
4. Check that the server path is in your clipboard

## Option 2: Manual Installation

### Step 1: Install Dependencies

```bash
# Install Homebrew (if not already installed)
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# Install fswatch
brew install fswatch

# Install xbar (optional, for menu bar integration)
brew install --cask xbar
```

### Step 2: Configure SSH Access

```bash
# Generate SSH key if you don't have one
ssh-keygen -t rsa -b 4096 -C "your_email@example.com"

# Copy the public key to your server
ssh-copy-id username@your-server.com

# Test SSH connection
ssh username@your-server.com "echo 'SSH works!'"
```

### Step 3: Clone and Configure

```bash
# Clone the repository
git clone https://github.com/yourusername/claude-screenshot-uploader.git
cd claude-screenshot-uploader

# Copy to your home directory
cp -r . ~/claude-screenshot-uploader/

# Create configuration from template
cp config.example.sh ~/.claude-screenshot-uploader.conf

# Edit configuration with your server details
nano ~/.claude-screenshot-uploader.conf
```

Edit the configuration file:
```bash
SERVER_HOST="your-server.com"        # Your server
SERVER_USER="your-username"          # SSH username
SERVER_PATH="/tmp/screenshots"       # Remote path
LOCAL_SCREENSHOTS="$HOME/Screenshots"
AUTO_DELETE="false"
```

### Step 4: Install the Service

```bash
# Copy LaunchAgent plist
cp com.claudecode.screenshot-uploader.plist ~/Library/LaunchAgents/

# Fix the script path in the plist
sed -i '' "s|~/claude-screenshot-uploader|$HOME/claude-screenshot-uploader|g" ~/Library/LaunchAgents/com.claudecode.screenshot-uploader.plist

# Load the service
launchctl load ~/Library/LaunchAgents/com.claudecode.screenshot-uploader.plist
```

### Step 5: Configure Screenshot Location

```bash
# Change macOS screenshot save location
defaults write com.apple.screencapture location ~/Screenshots

# Create the directory
mkdir -p ~/Screenshots

# Restart SystemUIServer to apply changes
killall SystemUIServer
```

### Step 6: Install xbar Plugin (Optional)

```bash
# Ensure xbar plugins directory exists
mkdir -p ~/Library/Application\ Support/xbar/plugins/

# Copy the plugin
cp xbar/screenshot-uploader.1s.sh ~/Library/Application\ Support/xbar/plugins/

# Make executable
chmod +x ~/Library/Application\ Support/xbar/plugins/screenshot-uploader.1s.sh

# Restart xbar
killall xbar 2>/dev/null || true
open -a xbar
```

## Verification

### 1. Check Service Status
```bash
# Check if service is running
launchctl list | grep com.claudecode.screenshot-uploader

# Check logs
tail -f /tmp/screenshot-uploader.log
```

### 2. Test Screenshot Upload

1. Take a screenshot: `Cmd + Shift + 4`
2. Check it was saved to `~/Screenshots/`
3. Wait a moment for upload
4. Check your clipboard: `pbpaste`
5. Verify file exists on server:
   ```bash
   ssh username@server "ls -la /tmp/screenshots/"
   ```

### 3. Check xbar Integration

- Look for 📸 icon in menu bar
- Icon should be green (🟢) when ready
- Click to see service controls and recent activity

## Troubleshooting Installation

### Common Issues

**1. Permission Denied Errors**
```bash
# Give Terminal access to Desktop/Documents folders
# System Settings → Privacy & Security → Files and Folders → Terminal
```

**2. SSH Connection Issues**
```bash
# Test SSH connection
ssh -v username@server

# Check SSH key
cat ~/.ssh/id_rsa.pub
```

**3. Service Won't Start**
```bash
# Check for errors
cat /tmp/screenshot-uploader-error.log

# Manually test script
~/claude-screenshot-uploader/screenshot_uploader.sh
```

**4. Screenshots Not Detected**
```bash
# Check screenshot location
defaults read com.apple.screencapture location

# Verify fswatch is working
fswatch -1 ~/Screenshots
```

### Getting Help

If you encounter issues:

1. Check the logs:
   ```bash
   tail -30 /tmp/screenshot-uploader.log
   tail -30 /tmp/screenshot-uploader-error.log
   ```

2. Test components individually:
   ```bash
   # Test SSH
   ssh username@server "echo test"
   
   # Test rsync
   rsync -av ~/Desktop/test.txt username@server:/tmp/
   
   # Test fswatch
   fswatch -1 ~/Screenshots
   ```

3. Open an issue on GitHub with:
   - Your macOS version
   - Error logs
   - Steps you've tried

## Manual Uninstall

If you need to remove everything manually:

```bash
# Stop and remove service
launchctl unload ~/Library/LaunchAgents/com.claudecode.screenshot-uploader.plist
rm ~/Library/LaunchAgents/com.claudecode.screenshot-uploader.plist

# Remove xbar plugin
rm ~/Library/Application\ Support/xbar/plugins/screenshot-uploader.1s.sh

# Remove scripts and config
rm -rf ~/claude-screenshot-uploader/
rm ~/.claude-screenshot-uploader.conf

# Clean up logs
rm /tmp/screenshot-uploader*

# Reset screenshot location (optional)
defaults delete com.apple.screencapture location
killall SystemUIServer
```

## Next Steps

After successful installation:

1. Customize your configuration in `~/.claude-screenshot-uploader.conf`
2. Consider setting `AUTO_DELETE="true"` if you don't want to keep local copies
3. Explore the xbar menu for service controls and monitoring
4. Read the main [README](README.md) for usage instructions