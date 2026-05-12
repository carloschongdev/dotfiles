#!/usr/bin/env bash
set -euo pipefail

DOTFILES_DIR="${DOTFILES_DIR:-$HOME/dotfiles}"
source "$DOTFILES_DIR/lib/logging.sh"

log "Configuring macOS..."

# ---------------------------------
# Appearance
# ---------------------------------

log "Setting dark mode..."
osascript -e 'tell app "System Events" to tell appearance preferences to set dark mode to true' 2>/dev/null && ok "Dark mode enabled." || warn "Could not set dark mode via osascript."

# ---------------------------------
# Wallpaper
# ---------------------------------

log "Setting wallpaper..."

WALLPAPER="$DOTFILES_DIR/macos/Wallpaper.png"

if [ -f "$WALLPAPER" ]; then
  osascript -e "tell application \"System Events\" to tell every desktop to set picture to \"$WALLPAPER\""
  ok "Wallpaper set from $WALLPAPER"
else
  warn "Wallpaper.png not found in macos/ — skipping."
  warn "To set a wallpaper, add Wallpaper.png to the macos/ folder."
fi

# ---------------------------------
# Display resolution (maximum for this model)
# ---------------------------------

log "Configuring display resolution..."

if command -v displayplacer &> /dev/null; then
  MODEL=$(system_profiler SPHardwareDataType 2>/dev/null | grep "Model Name" | awk -F: '{print $2}' | xargs)
  SCREEN_ID=$(displayplacer list 2>/dev/null | grep "Persistent screen id" | awk '{print $4}' | head -1)

  if [ -n "$SCREEN_ID" ]; then
    case "$MODEL" in
      *"MacBook Air"*)
        CHIP=$(sysctl -n machdep.cpu.brand_string 2>/dev/null)
        if echo "$CHIP" | grep -qE "M3|M4"; then
          displayplacer "id:$SCREEN_ID mode:11" 2>/dev/null && ok "Resolution set to 2048x1332 (Air M3/M4)." || warn "Could not set resolution."
        else
          displayplacer "id:$SCREEN_ID mode:11" 2>/dev/null && ok "Resolution set to 2048x1332 (Air M1/M2)." || warn "Could not set resolution."
        fi
        ;;
      *"MacBook Pro"*)
        SCREEN_WIDTH=$(displayplacer list 2>/dev/null | grep "Resolution:" | head -1 | grep -o '[0-9]*x' | head -1 | tr -d 'x')
        if [ "${SCREEN_WIDTH:-0}" -ge 3400 ]; then
          displayplacer "id:$SCREEN_ID mode:11" 2>/dev/null && ok "Resolution set (Pro 16\")." || warn "Could not set resolution."
        else
          displayplacer "id:$SCREEN_ID mode:11" 2>/dev/null && ok "Resolution set (Pro 14\")." || warn "Could not set resolution."
        fi
        ;;
      *)
        warn "Unknown model '$MODEL' — skipping resolution config."
        ;;
    esac
  else
    warn "Could not detect screen ID — skipping resolution config."
  fi
else
  warn "displayplacer not found — skipping resolution config."
fi

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

# ---------------------------------
# Touch ID for sudo
# ---------------------------------

log "Configuring Touch ID for sudo..."

if ! grep -q "pam_tid.so" /etc/pam.d/sudo 2>/dev/null; then
  sudo sed -i '' '/^# sudo: auth account password session/a\
auth       sufficient     pam_tid.so
' /etc/pam.d/sudo
  ok "Touch ID for sudo enabled."
else
  ok "Touch ID for sudo already configured."
fi

# Restart Finder & Dock to apply settings
killall Finder
killall Dock

ok "macOS configuration complete."
