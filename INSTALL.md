# Manual installation

`./setup.sh` handles everything described here. Follow this only if you want to
install by hand or need to understand what the installer does.

See the [README](README.md) for requirements, configuration and troubleshooting.

## 1. Copy the files

```bash
git clone https://github.com/mdrzn/claude-screenshot-uploader.git ~/claude-screenshot-uploader
cd ~/claude-screenshot-uploader
chmod +x uploader-*.sh helpers/*.sh xbar/*.sh setup.sh uninstall.sh migrate-config.sh
```

Installing to `~/claude-screenshot-uploader` matters: the xbar plugin looks there
for `helpers/`, and keeping it a git clone is what lets the menu update itself.

## 2. Set up SSH keys

Uploads run with `BatchMode=yes` and never prompt, so this has to work first:

```bash
ssh-copy-id you@example.com
ssh -o BatchMode=yes you@example.com "echo ok"
```

## 3. Write the config

```bash
mkdir -p ~/.claude-screenshot-uploader
cat > ~/.claude-screenshot-uploader/config.json <<'JSON'
{
  "active": "main",
  "local_screenshots": "/Users/you/Screenshots",
  "servers": {
    "main": {
      "name": "Production",
      "host": "example.com",
      "user": "root",
      "path": "/tmp/screenshots",
      "auto_delete": false
    }
  }
}
JSON
mkdir -p ~/Screenshots
```

Use an absolute path for `local_screenshots`. Coming from a 1.x `.conf` install,
run `./migrate-config.sh` instead of writing this by hand.

## 4. Install the xbar plugin

```bash
mkdir -p ~/Library/Application\ Support/xbar/plugins
cp xbar/screenshot-uploader.5s.sh ~/Library/Application\ Support/xbar/plugins/
chmod +x ~/Library/Application\ Support/xbar/plugins/screenshot-uploader.5s.sh
killall xbar 2>/dev/null; open -a xbar
```

Keep the `.5s.` in the filename — it is xbar's refresh interval, and xbar ignores
plugins without one.

At this point manual uploads work. Everything below is only for automatic modes.

## 5. Install a daemon (optional)

Pick one mode: `polling`, `watchpaths` or `fswatch`. The plists ship with
placeholders because `launchd` expands neither `~` nor environment variables.

```bash
MODE=polling
LABEL="com.claudecode.screenshot-uploader.$MODE"

sed -e "s|__INSTALL_DIR__|$HOME/claude-screenshot-uploader|g" \
    -e "s|__HOME__|$HOME|g" \
    -e "s|__SCREENSHOTS_DIR__|$HOME/Screenshots|g" \
    "$LABEL.plist" > "$HOME/Library/LaunchAgents/$LABEL.plist"

launchctl load "$HOME/Library/LaunchAgents/$LABEL.plist"
```

`fswatch` mode also needs `brew install fswatch`.

Install only one mode. Each has its own `Label`, so loading two leaves both
daemons uploading the same screenshots.

## 6. Point macOS at the folder (optional)

Skip this if a third-party capture tool already writes there.

```bash
defaults write com.apple.screencapture location ~/Screenshots
killall SystemUIServer
```

## Verify

```bash
launchctl list | grep screenshot        # loaded agent, exit status 0
tail -f /tmp/screenshot-uploader.log    # uploads appear here

# render the plugin the way xbar does
bash ~/Library/Application\ Support/xbar/plugins/screenshot-uploader.5s.sh
```

A non-zero exit status in `launchctl list` usually means the plist points at a
script that isn't there, or isn't executable.

## Manual uninstall

`./uninstall.sh` does this for you.

```bash
for p in ~/Library/LaunchAgents/com.claudecode.screenshot-uploader*.plist; do
  launchctl unload "$p" 2>/dev/null; rm -f "$p"
done
rm -f ~/Library/Application\ Support/xbar/plugins/screenshot-uploader*.sh
rm -rf ~/claude-screenshot-uploader ~/.claude-screenshot-uploader
rm -f ~/.claude-screenshot-uploader.conf /tmp/screenshot-uploader*
defaults delete com.apple.screencapture location 2>/dev/null; killall SystemUIServer
```
