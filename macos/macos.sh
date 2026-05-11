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

# ---------------------------------
# Screenshots
# ---------------------------------

log "Configuring screenshots..."
mkdir -p "$HOME/Desktop/Screenshots"
defaults write com.apple.screencapture location "$HOME/Desktop/Screenshots"
defaults write com.apple.screencapture disable-shadow -bool true
ok "Screenshots configured."

# ---------------------------------
# Mission Control
# ---------------------------------

log "Configuring Mission Control..."
defaults write com.apple.dock expose-animation-duration -float 0.1
ok "Mission Control animation speed set."

# ---------------------------------
# Menu Bar
# ---------------------------------

log "Configuring Menu Bar..."
defaults -currentHost write com.apple.controlcenter BatteryShowPercentage -bool true
ok "Battery percentage enabled."

# ---------------------------------
# Input
# ---------------------------------

log "Configuring input settings..."
defaults write NSGlobalDomain NSAutomaticSpellingCorrectionEnabled -bool false
ok "Auto-correction disabled."

# Restart Finder & Dock to apply settings
killall Finder
killall Dock

# ---------------------------------
# Dock apps (dockutil)
# ---------------------------------

if command -v dockutil &> /dev/null; then
  case "${DOTFILES_PROFILE:-both}" in
    personal) bash "$DOTFILES_DIR/macos/dock-personal.sh" ;;
    work)     bash "$DOTFILES_DIR/macos/dock-work.sh" ;;
    *)        bash "$DOTFILES_DIR/macos/dock-both.sh" ;;
  esac
else
  warn "dockutil not found — skipping Dock app layout."
fi

ok "macOS configuration complete."
