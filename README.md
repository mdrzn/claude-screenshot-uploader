# 📸 Claude Screenshot Uploader

Take a screenshot on your Mac, get a path you can paste straight into a remote Claude Code session.

![Platform](https://img.shields.io/badge/platform-macOS-blue.svg)
![License](https://img.shields.io/badge/license-MIT-green.svg)
![Version](https://img.shields.io/badge/version-3.1.0-orange.svg)

## 🤔 Why

When Claude Code runs on a remote server over SSH, it can read files on *that* server — not the image sitting on your Mac's desktop. Pasting a screenshot into the terminal does nothing useful, so you end up repeating the same four steps by hand: save the image, `scp` it up, work out where it landed, type the path.

This collapses that into one step. Your screenshot ends up on the server and its remote path ends up on your clipboard, so the only thing left to do is paste.

```
You: have a look at this — /tmp/screenshots/SCR-20260804-kurv.png
Claude: [reads the image]
```

## ⚙️ How it works

1. 📷 You take a screenshot, which lands in a folder you nominate.
2. 📤 It gets copied to your server over SSH with `rsync`.
3. 📋 The remote path goes on your clipboard, and a notification confirms it.

## ✨ Features

- 🖥️ **Multiple servers** — keep as many as you like and switch between them from the menu bar.
- 🎛️ **Four upload modes** — one click by hand, or fully automatic. Pick per install.
- 📋 **Clipboard handoff** — the remote path is ready to paste before the notification fades.
- 🔒 **SSH keys only** — no passwords are asked for, prompted for, or stored anywhere.
- 🔔 **Native notifications** — including when an upload fails, so it never fails silently.
- 🗑️ **Optional cleanup** — delete the local copy once it's safely uploaded, per server.
- ⬆️ **Update checks** — the menu tells you when a new version is out and updates in place.
- 📊 **Activity log** — the last few uploads are visible right in the menu.

## 📋 Requirements

- macOS
- [xbar](https://xbarapp.com) — provides the menu bar icon
- A server you can reach over SSH with key authentication
- `python3` and `rsync` — `rsync` ships with macOS, `python3` comes with the Xcode command line tools (`xcode-select --install`)
- `fswatch` — only for the `fswatch` upload mode (`brew install fswatch`)

## 🚀 Install

```bash
git clone https://github.com/mdrzn/claude-screenshot-uploader.git
cd claude-screenshot-uploader
./setup.sh
```

The installer asks for your server details, checks that SSH works, lets you choose an upload mode, installs the xbar plugin, and offers to point macOS at your screenshots folder.

> 💡 Cloning to `~/claude-screenshot-uploader` lets the tool update itself later with a `git pull`. Anywhere else works fine, but you'll update by hand.

## 📸 Usage

Take a screenshot, then click 📸 in the menu bar and choose **Upload**. The path is on your clipboard.

The icon shows where uploads are headed at a glance:

| Icon | Meaning |
|:--|:--|
| `📸 → your-server` | Ready, pointed at that server |
| `📸 🔵` | Upload in progress |
| `📸` | No server selected yet |
| `📸 ⚠️` | Not configured, or the config can't be read |

## 🎛️ Upload modes

Switch any time from **⚡ Upload Mode** in the menu — it shows which mode is active and swaps it in one click. `setup.sh` also asks during install.

| Mode | How it triggers | Trade-off |
|:--|:--|:--|
| **Manual** | You click Upload | Nothing runs in the background. You decide what gets uploaded. |
| **Polling** | A daemon checks every 2s | The most dependable automatic mode. Costs a wakeup every couple of seconds. |
| **WatchPaths** | `launchd` watches the folder | Idle until something changes, but rapid bursts of screenshots can collapse into one upload. |
| **fswatch** | A resident watcher | Uploads start immediately. Needs `fswatch` and a long-lived process staying healthy. |

Manual mode suits most people: it keeps uploads deliberate and leaves nothing running. Reach for an automatic mode when you're taking screenshots continuously and don't want to click each time.

Only one mode is ever installed — switching removes the previous one first, so two daemons can't race to upload the same file. Manual mode is simply the absence of a daemon, and the manual **Upload** button stays available in every mode.

The automatic modes upload the *newest* screenshot they find. Two screenshots landing inside the same interval means the older one is skipped, so use manual mode when you need every single capture.

## 🔧 Configuration

Servers live in `~/.claude-screenshot-uploader/config.json`. Use **Server Management** in the menu rather than editing it by hand.

```json
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
```

| Field | Meaning |
|:--|:--|
| `active` | Key of the server uploads go to |
| `local_screenshots` | Folder that gets watched |
| `name` | Label shown in the menu |
| `host` / `user` | SSH target |
| `path` | Remote directory to upload into |
| `auto_delete` | Delete the local copy after a successful upload |

Any `.png`, `.jpg` or `.jpeg` in the watched folder counts as a screenshot, so this works with the built-in macOS capture as well as tools like Shottr or CleanShot, whatever they name their files.

### 🔑 SSH keys

Uploads run with `BatchMode=yes` and never prompt, so key authentication has to be set up first:

```bash
ssh-keygen -t ed25519          # if you don't already have a key
ssh-copy-id you@example.com
ssh you@example.com "echo ok"  # should print ok without asking for anything
```

A host's key is trusted on first contact and pinned after that, so if it later changes the upload fails loudly instead of going through quietly.

## ⬆️ Updating

The menu checks GitHub once a day and shows **⬆️ Update available** when there's a newer release. **Update now** pulls it, reinstalls the plugin, and restarts the daemon.

The check only ever reads a cached answer, so a slow or unreachable GitHub can't stall your menu bar. It refuses to run over uncommitted local changes.

To update by hand:

```bash
cd ~/claude-screenshot-uploader && git pull && ./setup.sh
```

## 🎚️ Service control

Automatic modes install a LaunchAgent labelled `com.claudecode.screenshot-uploader.<mode>`.

```bash
launchctl list | grep screenshot     # which mode is loaded
tail -f /tmp/screenshot-uploader.log # watch uploads happen

# stop / start (substitute your mode: polling, watchpaths, fswatch)
launchctl unload ~/Library/LaunchAgents/com.claudecode.screenshot-uploader.polling.plist
launchctl load   ~/Library/LaunchAgents/com.claudecode.screenshot-uploader.polling.plist
```

## 🐛 Troubleshooting

<details>
<summary>Nothing uploads</summary>

Check SSH works without a prompt, since uploads never ask for input:

```bash
ssh -o BatchMode=yes you@example.com "echo ok"
```

Then check the logs — failures are recorded with the `rsync` error:

```bash
tail -20 /tmp/screenshot-uploader.log
tail -20 /tmp/screenshot-uploader-error.log
```
</details>

<details>
<summary>The menu says "Not Configured"</summary>

There's no `~/.claude-screenshot-uploader/config.json` yet. Add a server from the menu, or re-run `./setup.sh`. Coming from a single-server `.conf` file? Run `./migrate-config.sh` to convert it.
</details>

<details>
<summary>Screenshots aren't landing in the watched folder</summary>

Check where macOS is putting them, and what the tool is watching:

```bash
defaults read com.apple.screencapture location
python3 -c "import json;print(json.load(open('$HOME/.claude-screenshot-uploader/config.json'))['local_screenshots'])"
```

If you capture with a third-party tool, point that tool at the same folder.
</details>

<details>
<summary>No menu bar icon</summary>

Confirm xbar is running and the plugin is installed and executable:

```bash
ls -l ~/Library/Application\ Support/xbar/plugins/screenshot-uploader.5s.sh
```

Then refresh xbar with ⌘R. The `5s` in the filename is its refresh interval — xbar won't load a plugin without one.
</details>

<details>
<summary>The icon is stuck showing an upload</summary>

A status file left behind by an interrupted upload is ignored after 60 seconds and cleared automatically. To clear it immediately:

```bash
rm -f /tmp/screenshot-uploader-status
```
</details>

## 📂 Layout

```
uploader-polling.sh          # daemon: fixed interval
uploader-watchpaths.sh       # daemon: launchd WatchPaths
uploader-fswatch.sh          # daemon: resident fswatch
uploader-fswatch-legacy.sh   # daemon: fswatch, single-server .conf format
helpers/common.sh            # shared config reading, upload path, logging
helpers/                     # menu actions: add/edit/remove/switch, upload, update
xbar/screenshot-uploader.5s.sh   # the menu bar plugin
com.claudecode.*.plist       # LaunchAgent templates, one per mode
```

Scripts are named for the mode they implement. Every upload — manual or automatic — goes through `csu_upload` in `helpers/common.sh`, so the status file, clipboard, logging and notifications behave identically no matter what triggered it.

## 🗑️ Uninstall

```bash
./uninstall.sh
```

Removes the LaunchAgent, the xbar plugin and the scripts. Asks before touching your configuration, and never deletes your screenshots.

## 📄 License

MIT — see [LICENSE](LICENSE).

---

Built for [Claude Code](https://claude.com/claude-code) users working over SSH.
