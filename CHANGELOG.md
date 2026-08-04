# Changelog

All notable changes to this project are documented here.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project follows [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [2.0.0] - 2026-08-04

### Added
- Multiple server profiles in `~/.claude-screenshot-uploader/config.json`, with switching, adding, editing and removing from the menu bar.
- Manual upload mode: upload the newest screenshot on demand from the menu, with no background daemon.
- Four selectable upload modes — manual, polling, WatchPaths and fswatch — chosen during `setup.sh`.
- Daily update check against GitHub releases, surfaced in the menu with a one-click in-place updater (`helpers/self-update.sh`). The check reads a cached answer only, so the menu never waits on the network.
- `helpers/common.sh`, holding the single upload path (`csu_upload`) plus shared config reading, logging and screenshot discovery used by every entry point.
- `VERSION` as the single source of truth for the version number, read at runtime by the plugin.
- `migrate-config.sh`, converting a single-server `.conf` install to `config.json`.
- Timestamped activity log at `/tmp/screenshot-uploader.log`, with the most recent uploads shown in the menu.

### Changed
- Scripts and LaunchAgent plists are named for the upload mode they implement rather than by version number.
- Each mode's plist carries its own `Label` (`com.claudecode.screenshot-uploader.<mode>`), and `setup.sh` removes any previously installed mode, so two daemons can no longer both upload the same file.
- Plists ship with `__INSTALL_DIR__` / `__HOME__` / `__SCREENSHOTS_DIR__` placeholders substituted at install time, instead of carrying absolute paths.
- Any `.png`, `.jpg` or `.jpeg` in the watched folder is treated as a screenshot, rather than only files matching `SCR-*.png`. Third-party capture tools and non-English macOS installs work without configuration.
- `setup.sh` writes `config.json`, asks which upload mode to install, and asks before changing the macOS screenshot location instead of changing it unprompted.
- SSH host keys use `StrictHostKeyChecking=accept-new`: trusted on first contact, pinned afterwards, so a changed key fails loudly rather than being accepted silently.
- Server details reach `python3` through the environment instead of being interpolated into the script, so quotes and backslashes in a server name are handled correctly.
- Config writes go through a temporary file and an atomic rename, so an interrupted write cannot truncate the config.
- The xbar plugin refreshes every 5 seconds rather than every second, and reads the whole config in a single `python3` call.

### Fixed
- **Remove Server** always reported "No Servers": `$HOME` sat inside a quoted heredoc, so Python received the literal string and the server list came back empty.
- The **Test SSH Connection** menu item connected as the local macOS user, ignoring the `user` field in the config.
- Server names containing a colon corrupted the menu, since config rows were colon-delimited. Rows are tab-delimited now, with tabs stripped from values.
- Finding the newest screenshot piped every filename into `ls -t`, which sorts each `xargs` batch separately and returns the newest file of the first batch once the folder grows past the argument limit. Selection is now by `stat` mtime.
- A config that was missing or unparseable produced a menu offering to upload to an empty server name, instead of reporting the error.
- A status file left behind by an interrupted upload pinned the menu bar on the uploading icon indefinitely. Stale files are now ignored after 60 seconds.
- Manual uploads never reached the activity log, leaving the menu's recent activity permanently empty in manual mode.
- The plugin computed a status string that was never displayed.
- `WorkingDirectory` in two plists was `~/`, which `launchd` does not expand.
- The plugin read `~/Screenshots` directly while the daemons honoured `local_screenshots`, so a custom folder worked for automatic uploads but not manual ones.
- `migrate-config.sh` built JSON by string interpolation, producing an unparseable config from any value containing a quote, or from an `AUTO_DELETE` that wasn't exactly `true` or `false`.

### Removed
- `helpers/add-server-simple.sh` and `helpers/quick-edit.sh`, unreferenced duplicates of `add-server.sh` and `edit-server.sh`.

## [1.0.0] - 2025-09-10

### Added
- Initial release: automatic screenshot upload over SSH with `rsync`, driven by `fswatch`.
- Single server configured through `~/.claude-screenshot-uploader.conf`.
- xbar plugin showing daemon status and recent activity.
- Remote path copied to the clipboard after each upload.
- `launchd` background service, plus setup and uninstall scripts.
- Optional deletion of local screenshots after upload.

[2.0.0]: https://github.com/mdrzn/claude-screenshot-uploader/releases/tag/v2.0.0
[1.0.0]: https://github.com/mdrzn/claude-screenshot-uploader/releases/tag/v1.0.0
