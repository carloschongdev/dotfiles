#!/usr/bin/env bash
set -euo pipefail

DOTFILES_DIR="${DOTFILES_DIR:-$HOME/dotfiles}"
source "$DOTFILES_DIR/lib/logging.sh"

log "Configuring macOS..."

# ---------------------------------
# Keyboard
# ---------------------------------

defaults write NSGlobalDomain KeyRepeat -int 2
defaults write NSGlobalDomain InitialKeyRepeat -int 15
ok "Keyboard repeat rate set."

# ---------------------------------
# Finder
# ---------------------------------

defaults write com.apple.finder AppleShowAllFiles -bool true
defaults write com.apple.finder ShowPathbar -bool true
ok "Finder configured."

# ---------------------------------
# Dock settings
# ---------------------------------

log "Configuring Dock settings..."

defaults write com.apple.dock orientation         -string "left"
defaults write com.apple.dock tilesize            -int 48
defaults write com.apple.dock autohide            -bool false
defaults write com.apple.dock autohide-time-modifier -float 0.5
defaults write com.apple.dock autohide-delay      -float 0
defaults write com.apple.dock show-recents        -bool false

ok "Dock settings applied."

# Restart Finder & Dock to apply settings
killall Finder
killall Dock

# ---------------------------------
# Dock apps (dockutil)
# ---------------------------------

if command -v dockutil &> /dev/null; then
  bash "$DOTFILES_DIR/macos/dock.sh"
else
  warn "dockutil not found — skipping Dock app layout."
fi

ok "macOS configuration complete."
