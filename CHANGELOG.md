# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.0] - 2025-09-10

### Added
- Initial release of Claude Screenshot Uploader
- Automatic screenshot detection and upload via SSH/rsync
- Real-time file monitoring with fswatch
- xbar menu bar integration with status indicators
- Automatic clipboard integration for server paths
- Background service with launchd
- Comprehensive setup and uninstall scripts
- Configuration system with template
- Support for SSH key authentication
- Visual status indicators (🟢🟡🔴) during upload
- Optional auto-deletion of local screenshots
- Comprehensive documentation and troubleshooting guide

### Features
- **Automatic Detection**: Monitors ~/Screenshots for new SCR-*.png files
- **Instant Upload**: Uses rsync over SSH for efficient transfers
- **Clipboard Integration**: Server paths automatically copied and ready to paste
- **Visual Feedback**: xbar plugin shows upload status in menu bar
- **Zero Configuration**: Setup script handles all dependencies and configuration
- **Security**: Uses SSH key authentication, no passwords stored
- **Performance**: Smart transfers with duplicate detection
- **Reliability**: Background service with automatic restart

### Requirements
- macOS 10.15 (Catalina) or later
- SSH access to remote server
- Homebrew (automatically installed by setup script)
- xbar (optional, for menu bar status)

### Initial Contributors
- Initial development and architecture
- Documentation and user experience design
- Testing and bug fixes

[1.0.0]: https://github.com/yourusername/claude-screenshot-uploader/releases/tag/v1.0.0