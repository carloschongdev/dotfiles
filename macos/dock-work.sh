#!/usr/bin/env bash
set -euo pipefail

DOTFILES_DIR="${DOTFILES_DIR:-$HOME/dotfiles}"
source "$DOTFILES_DIR/lib/logging.sh"

log "Configuring Dock (work)..."

# Only add app if it's installed
add_app() {
  if [ -d "$1" ]; then
    dockutil --add "$1" --no-restart
  else
    warn "Skipping $(basename "$1") — not installed"
  fi
}

# Reset Dock completely before configuring
log "Resetting Dock..."
defaults delete com.apple.dock persistent-apps 2>/dev/null || true
defaults delete com.apple.dock persistent-others 2>/dev/null || true
killall Dock 2>/dev/null || true
sleep 2

# Clear Dock
dockutil --remove all --no-restart

# ---------------------------------
# System Apps
# ---------------------------------

add_app "/System/Applications/Apps.app"
add_app "/System/Applications/Passwords.app"
add_app "/System/Applications/Notes.app"
add_app "/System/Applications/App Store.app"
add_app "/System/Applications/System Settings.app"
add_app "/System/Applications/iPhone Mirroring.app"

# ---------------------------------
# Browsers
# ---------------------------------

add_app "/System/Volumes/Preboot/Cryptexes/App/System/Applications/Safari.app"
add_app "/Applications/Google Chrome.app"
add_app "/Applications/Brave Browser.app"

# ---------------------------------
# Microsoft / Work
# ---------------------------------

add_app "/Applications/Microsoft Outlook.app"

# ---------------------------------
# Communication
# ---------------------------------

add_app "/Applications/WhatsApp.app"

# ---------------------------------
# AI / Tools
# ---------------------------------

add_app "/Applications/Claude.app"

# ---------------------------------
# Terminal / Dev
# ---------------------------------

add_app "/System/Applications/Utilities/Terminal.app"
add_app "/Applications/Ghostty.app"
add_app "/Applications/Visual Studio Code.app"
add_app "/Applications/Linear.app"

# ---------------------------------
# Spacer + Downloads folder
# ---------------------------------

dockutil --add '' --type spacer --no-restart
dockutil --add ~/Downloads --view fan --display stack

killall Dock 2>/dev/null || true

ok "Dock configured (work)."
