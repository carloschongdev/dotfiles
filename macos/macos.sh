#!/usr/bin/env bash
set -euo pipefail

DOTFILES_DIR="${DOTFILES_DIR:-$HOME/dotfiles}"
source "$DOTFILES_DIR/lib/logging.sh"

log "Configuring macOS..."

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

# ---------------------------------
# Appearance
# ---------------------------------

log "Setting dark mode..."
defaults write NSGlobalDomain AppleInterfaceStyle -string "Dark"
ok "Dark mode enabled."

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
        # M1/M2 Air: 2560x1664, M3/M4 Air: 2960x1872
        CHIP=$(sysctl -n machdep.cpu.brand_string 2>/dev/null)
        if echo "$CHIP" | grep -qE "M3|M4"; then
          displayplacer "id:$SCREEN_ID res:2960x1872 scaling:on origin:(0,0) degree:0" 2>/dev/null && ok "Resolution set to 2960x1872 (Air M3/M4)." || warn "Could not set resolution."
        else
          displayplacer "id:$SCREEN_ID res:2560x1664 scaling:on origin:(0,0) degree:0" 2>/dev/null && ok "Resolution set to 2560x1664 (Air M1/M2)." || warn "Could not set resolution."
        fi
        ;;
      *"MacBook Pro"*)
        # 14" Pro: 3024x1964, 16" Pro: 3456x2234
        SCREEN_WIDTH=$(displayplacer list 2>/dev/null | grep "resolution" | head -1 | grep -o '[0-9]*x[0-9]*' | head -1 | cut -dx -f1)
        if [ "${SCREEN_WIDTH:-0}" -ge 3400 ]; then
          displayplacer "id:$SCREEN_ID res:3456x2234 scaling:on origin:(0,0) degree:0" 2>/dev/null && ok "Resolution set to 3456x2234 (Pro 16\")." || warn "Could not set resolution."
        else
          displayplacer "id:$SCREEN_ID res:3024x1964 scaling:on origin:(0,0) degree:0" 2>/dev/null && ok "Resolution set to 3024x1964 (Pro 14\")." || warn "Could not set resolution."
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

ok "macOS configuration complete."
