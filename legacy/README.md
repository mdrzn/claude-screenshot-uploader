# Legacy: v3 (shell scripts + xbar)

This folder keeps the previous version of Claude Screenshot Uploader — shell scripts run by launchd, with a menu provided by [xbar](https://xbarapp.com) — for reference. It has been replaced by the native Mac app in [`app/`](../app).

- To use v3 as it was, check out the [`v3-shell`](https://github.com/mdrzn/claude-screenshot-uploader/tree/v3-shell) branch or the [v3.1.0 release](https://github.com/mdrzn/claude-screenshot-uploader/releases/tag/v3.1.0); its documentation is in the [v3.1.0 README](https://github.com/mdrzn/claude-screenshot-uploader/blob/v3.1.0/README.md). The scripts here expect to live at the repository root, so run them from that branch rather than from this folder.
- To upgrade, install the native app: it reads the same `~/.claude-screenshot-uploader/config.json` and offers to turn this version off.
