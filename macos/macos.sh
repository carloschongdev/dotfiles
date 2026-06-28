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
# Display resolution
# ---------------------------------

log "Configuring display resolution..."

if command -v displayplacer &> /dev/null; then
  SCREEN_ID=$(displayplacer list 2>/dev/null | grep "Persistent screen id" | awk '{print $4}' | head -1)

  if [ -n "$SCREEN_ID" ]; then
    MODEL=$(system_profiler SPHardwareDataType 2>/dev/null | grep "Model Name" | awk -F: '{print $2}' | xargs)
    CHIP=$(sysctl -n machdep.cpu.brand_string 2>/dev/null)

    # Detect recommended mode based on model
    case "$MODEL" in
      *"MacBook Air"*)
        if echo "$CHIP" | grep -qE "M3|M4"; then
          RECOMMENDED_MODE=11
          RECOMMENDED_RES="2048x1332"
        else
          RECOMMENDED_MODE=11
          RECOMMENDED_RES="2048x1332"
        fi
        ;;
      *"MacBook Pro"*)
        RECOMMENDED_MODE=6
        RECOMMENDED_RES="2048x1280"
        ;;
      *)
        RECOMMENDED_MODE=6
        RECOMMENDED_RES="best available"
        ;;
    esac

    echo ""
    echo "  Model: $MODEL ($CHIP)"
    echo "  Available resolutions:"
    echo ""
    displayplacer list 2>/dev/null | grep "mode [0-9]" | while read -r line; do
      echo "    $line"
    done
    echo ""
    echo "  Recommended mode: $RECOMMENDED_MODE ($RECOMMENDED_RES)"
    echo "  Enter mode number to apply, 's' to skip, or press Enter for recommended."
    echo "  (Auto-applying recommended in 10 seconds...)"
    echo ""

    if read -rt 10 -rp "  Mode [Enter=$RECOMMENDED_MODE]: " CHOSEN_MODE < /dev/tty; then
      if [[ "$CHOSEN_MODE" == "s" || "$CHOSEN_MODE" == "S" ]]; then
        warn "Skipping resolution configuration."
      elif [[ -z "$CHOSEN_MODE" ]]; then
        displayplacer "id:$SCREEN_ID mode:$RECOMMENDED_MODE" 2>/dev/null && ok "Resolution set to mode $RECOMMENDED_MODE ($RECOMMENDED_RES)." || warn "Could not set resolution."
      elif [[ "$CHOSEN_MODE" =~ ^[0-9]+$ ]]; then
        displayplacer "id:$SCREEN_ID mode:$CHOSEN_MODE" 2>/dev/null && ok "Resolution set to mode $CHOSEN_MODE." || warn "Could not set resolution — invalid mode?"
      else
        warn "Invalid input — skipping resolution configuration."
      fi
    else
      # Timeout — apply recommended
      echo ""
      displayplacer "id:$SCREEN_ID mode:$RECOMMENDED_MODE" 2>/dev/null && ok "Resolution set to mode $RECOMMENDED_MODE ($RECOMMENDED_RES) — auto-applied." || warn "Could not set resolution."
    fi
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

#defaults write com.apple.finder AppleShowAllFiles -bool true
defaults write com.apple.finder ShowPathbar -bool true
defaults write com.apple.finder FXPreferredViewStyle -string "icnv"
defaults write com.apple.finder FXArrangeGroupViewBy -string "name"
ok "Finder configured."

# ---------------------------------
# Dock settings
# ---------------------------------

log "Configuring Dock settings..."

defaults write com.apple.dock orientation         -string "left"
defaults write com.apple.dock tilesize            -int 48
defaults write com.apple.dock autohide            -bool true
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

# ---------------------------------
# Hot corners
# ---------------------------------

log "Configuring hot corners..."

# Top-left: Quick Note (14)
defaults write com.apple.dock wvous-tl-corner   -int 14
defaults write com.apple.dock wvous-tl-modifier -int 0

# Top-right: Mission Control (2)
defaults write com.apple.dock wvous-tr-corner   -int 2
defaults write com.apple.dock wvous-tr-modifier -int 0

# Bottom-left: Lock Screen (13)
defaults write com.apple.dock wvous-bl-corner   -int 13
defaults write com.apple.dock wvous-bl-modifier -int 0

# Bottom-right: Desktop (4)
defaults write com.apple.dock wvous-br-corner   -int 4
defaults write com.apple.dock wvous-br-modifier -int 0

ok "Hot corners configured."

# ---------------------------------
# Display sleep
# ---------------------------------

log "Configuring display sleep..."
sudo pmset -b displaysleep 5    # 5 min on battery
sudo pmset -c displaysleep 10   # 10 min on power adapter
ok "Display sleep configured (battery: 5min, adapter: 10min)."

# ---------------------------------
# Terminal.app defaults
# ---------------------------------

log "Configuring Terminal.app..."
defaults write com.apple.Terminal "Default Window Settings" -string "Pro"
defaults write com.apple.Terminal "Startup Window Settings" -string "Pro"
ok "Terminal.app set to Pro profile."

# Restart Finder & Dock to apply settings
killall Finder 2>/dev/null || true
killall Dock 2>/dev/null || true

ok "macOS configuration complete."
