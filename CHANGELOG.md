# Changelog

All notable changes to this dotfiles repo are documented here.

## [Unreleased]

## [2.0.0] - 2026-05-12
### Added
- Three-profile support: personal, work, both
- Separate Brewfiles per profile (Brewfile.personal, Brewfile.work, Brewfile.both)
- Dual SSH identity with named keys (id_carloschongdev_personal, id_CarlosChong28_work)
- Pre-push hook with account verification and non-interactive bypass
- chpwd function for automatic gh account switching by directory
- Git multi-identity via includeIf by directory
- Dark mode, wallpaper and display resolution configured automatically
- Touch ID for sudo configured automatically
- displayplacer installed early for visual config at bootstrap start
- Per-profile Dock scripts (dock-personal.sh, dock-work.sh, dock-both.sh)
- Bootstrap progress steps (Step X/10)
- Bootstrap summary with SSH public keys and next steps
- starship.toml configuration
- commit-msg hook for conventional commits
- verify.sh health check script
- update.sh maintenance script
- macOS defaults: screenshots location, Mission Control animation, battery %, auto-correction

### Changed
- Bootstrap order: visual config first, apps last
- Brewfile order: brew → cask → mas → Xcode (last)
- Removed deprecated taps: homebrew/cask-fonts, homebrew/services
- Moved WhatsApp and The Unarchiver from mas to cask
- Removed insteadOf SSH override (caused Homebrew failures on fresh install)
- Xcode removed from Brewfiles until needed

### Fixed
- pre-push hook non-interactive detection for Claude Code
- Bootstrap summary gh auth pipefail with set -euo pipefail
- dockutil and displayplacer moved after Brewfile installation

## [1.0.0] - 2026-04-17
### Added
- Initial dotfiles setup with GNU Stow
- Basic Brewfile with core tools
- zsh configuration (.zshrc, .aliases, .exports)
- Ghostty terminal configuration
- VS Code settings
- fastfetch with custom CC logo
- Git configuration with aliases
