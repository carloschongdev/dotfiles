#!/usr/bin/env bash
set -euo pipefail

DOTFILES_DIR="${DOTFILES_DIR:-$HOME/dotfiles}"
source "$DOTFILES_DIR/lib/logging.sh"

# Get a clean machine identifier: "MacBook-Air-M4", "MacBook-Pro-M1", etc.
MACHINE_MODEL=$(system_profiler SPHardwareDataType 2>/dev/null | grep "Model Name" | awk -F: '{print $2}' | xargs | tr ' ' '-')
MACHINE_CHIP=$(sysctl -n machdep.cpu.brand_string 2>/dev/null | grep -oE "M[0-9]" | head -1)
MACHINE_ID="${MACHINE_MODEL}-${MACHINE_CHIP}"

SNAPSHOT_DIR="$DOTFILES_DIR/snapshots/$MACHINE_ID"
rm -rf "$SNAPSHOT_DIR"
mkdir -p "$SNAPSHOT_DIR"

echo ""
echo "================================================"
echo "  DOTFILES SNAPSHOT"
echo "================================================"
echo ""

# ---------------------------------
# Helper: compare a default against expected baseline value
# ---------------------------------
# Usage: check_override <domain> <key> <expected_value> <description>
check_override() {
  local domain="$1"
  local key="$2"
  local expected="$3"
  local description="$4"
  local current

  current=$(defaults read "$domain" "$key" 2>/dev/null || echo "__NOTSET__")

  if [ "$current" == "__NOTSET__" ]; then
    return 0
  fi

  if [ "$current" != "$expected" ]; then
    echo "$domain|$key|$current|$description" >> "$SNAPSHOT_DIR/overrides.txt"
    ok "  Override detected: $description ($current, expected $expected)"
  fi
}

# ---------------------------------
# 1. Detect overrides vs bootstrap baseline
# ---------------------------------

log "Checking for manual overrides vs bootstrap defaults..."
touch "$SNAPSHOT_DIR/overrides.txt"

check_override "com.apple.dock" "autohide" "1" "Dock autohide"
check_override "com.apple.dock" "orientation" "left" "Dock position"
check_override "com.apple.dock" "tilesize" "48" "Dock icon size"
check_override "com.apple.dock" "show-recents" "0" "Dock show recents"
check_override "com.apple.finder" "AppleShowAllFiles" "0" "Finder show hidden files"
check_override "com.apple.finder" "ShowPathbar" "1" "Finder path bar"
check_override "com.apple.finder" "FXPreferredViewStyle" "icnv" "Finder view style"
check_override "NSGlobalDomain" "AppleInterfaceStyle" "Dark" "Dark mode"
check_override "com.apple.dock" "wvous-tl-corner" "14" "Hot corner top-left"
check_override "com.apple.dock" "wvous-tr-corner" "2" "Hot corner top-right"
check_override "com.apple.dock" "wvous-bl-corner" "13" "Hot corner bottom-left"
check_override "com.apple.dock" "wvous-br-corner" "4" "Hot corner bottom-right"
check_override "com.apple.screencapture" "disable-shadow" "1" "Screenshot shadow"
check_override "com.apple.menuextra.battery" "ShowPercent" "YES" "Battery percentage"
check_override "NSGlobalDomain" "NSAutomaticSpellingCorrectionEnabled" "0" "Auto-correction"

if [ -s "$SNAPSHOT_DIR/overrides.txt" ]; then
  ok "Found $(wc -l < "$SNAPSHOT_DIR/overrides.txt" | xargs) override(s) — saved to overrides.txt"
else
  ok "No overrides detected — system matches bootstrap defaults."
fi

# ---------------------------------
# 2. Display resolution (always capture — no fixed baseline, user choice)
# ---------------------------------

log "Capturing current display resolution..."
if command -v displayplacer &> /dev/null; then
  displayplacer list 2>/dev/null | grep -A 2 "current mode" > "$SNAPSHOT_DIR/resolution.txt" 2>/dev/null || true
  displayplacer list 2>/dev/null | grep "<-- current mode" > "$SNAPSHOT_DIR/resolution-mode.txt" 2>/dev/null || true
  ok "Resolution captured."
else
  warn "displayplacer not found — skipping resolution capture."
fi

# ---------------------------------
# 3. Trackpad and Mouse settings
# ---------------------------------

log "Capturing trackpad and mouse settings..."
{
  echo "trackpad_speed=$(defaults read -g com.apple.trackpad.scaling 2>/dev/null || echo 'default')"
  echo "mouse_speed=$(defaults read -g com.apple.mouse.scaling 2>/dev/null || echo 'default')"
  echo "tap_to_click=$(defaults read com.apple.AppleMultitouchTrackpad Clicking 2>/dev/null || echo 'default')"
} > "$SNAPSHOT_DIR/trackpad-mouse.txt"
ok "Trackpad and mouse settings captured."

# ---------------------------------
# 4. Keyboard
# ---------------------------------

log "Capturing keyboard settings..."
{
  echo "key_repeat=$(defaults read NSGlobalDomain KeyRepeat 2>/dev/null || echo 'default')"
  echo "initial_key_repeat=$(defaults read NSGlobalDomain InitialKeyRepeat 2>/dev/null || echo 'default')"
} > "$SNAPSHOT_DIR/keyboard.txt"
ok "Keyboard settings captured."

# ---------------------------------
# 5. Energy / pmset
# ---------------------------------

log "Capturing energy settings..."
pmset -g custom > "$SNAPSHOT_DIR/pmset.txt" 2>/dev/null || echo "Could not capture pmset" > "$SNAPSHOT_DIR/pmset.txt"
ok "Energy settings captured."

# ---------------------------------
# 6. Sound
# ---------------------------------

log "Capturing sound settings..."
{
  echo "volume=$(osascript -e 'output volume of (get volume settings)' 2>/dev/null || echo 'unknown')"
  echo "alert_volume=$(defaults read NSGlobalDomain com.apple.sound.beep.volume 2>/dev/null || echo 'default')"
} > "$SNAPSHOT_DIR/sound.txt"
ok "Sound settings captured."

# ---------------------------------
# 7. Language and region
# ---------------------------------

log "Capturing language and region..."
defaults read NSGlobalDomain AppleLanguages > "$SNAPSHOT_DIR/language.txt" 2>/dev/null || echo "default" > "$SNAPSHOT_DIR/language.txt"
defaults read NSGlobalDomain AppleLocale >> "$SNAPSHOT_DIR/language.txt" 2>/dev/null || true
ok "Language and region captured."

# ---------------------------------
# 8. Accessibility
# ---------------------------------

log "Capturing accessibility settings..."
{
  echo "reduce_motion=$(defaults read com.apple.universalaccess reduceMotion 2>/dev/null || echo 'default')"
  echo "reduce_transparency=$(defaults read com.apple.universalaccess reduceTransparency 2>/dev/null || echo 'default')"
  echo "increase_contrast=$(defaults read com.apple.universalaccess increaseContrast 2>/dev/null || echo 'default')"
} > "$SNAPSHOT_DIR/accessibility.txt"
ok "Accessibility settings captured."

# ---------------------------------
# 9. WiFi networks (names only, no passwords)
# ---------------------------------

log "Capturing known WiFi network names..."
networksetup -listpreferredwirelessnetworks en0 > "$SNAPSHOT_DIR/wifi-networks.txt" 2>/dev/null || echo "Could not list networks" > "$SNAPSHOT_DIR/wifi-networks.txt"
warn "WiFi passwords are in Keychain and cannot be exported — manual reconnection required."
ok "WiFi network names captured."

# ---------------------------------
# 10. Login Items and Launch Agents
# ---------------------------------

log "Capturing Login Items..."
osascript -e 'tell application "System Events" to get the name of every login item' > "$SNAPSHOT_DIR/login-items.txt" 2>/dev/null || echo "Could not read login items" > "$SNAPSHOT_DIR/login-items.txt"
ok "Login Items captured."

log "Capturing user Launch Agents..."
ls "$HOME/Library/LaunchAgents/" > "$SNAPSHOT_DIR/launch-agents.txt" 2>/dev/null || echo "None found" > "$SNAPSHOT_DIR/launch-agents.txt"
ok "Launch Agents captured."

# ---------------------------------
# 11. Installed applications
# ---------------------------------

log "Capturing installed applications..."

# Brew formulas and casks actually installed
brew bundle dump --file="$SNAPSHOT_DIR/Brewfile.snapshot" --force 2>/dev/null || warn "Could not dump Brewfile."

# App Store apps
if command -v mas &> /dev/null; then
  mas list > "$SNAPSHOT_DIR/mas-apps.txt" 2>/dev/null || echo "Could not list mas apps" > "$SNAPSHOT_DIR/mas-apps.txt"
fi

# Apps in /Applications not from brew/mas (manually installed)
ls /Applications > "$SNAPSHOT_DIR/all-applications.txt" 2>/dev/null || true

ok "Installed applications captured."

# ---------------------------------
# 12. VS Code extensions
# ---------------------------------

log "Capturing VS Code extensions..."
if command -v code &> /dev/null; then
  code --list-extensions > "$SNAPSHOT_DIR/vscode-extensions.txt" 2>/dev/null || echo "Could not list extensions" > "$SNAPSHOT_DIR/vscode-extensions.txt"
  ok "VS Code extensions captured."
else
  warn "VS Code CLI not found — skipping extensions."
fi

# ---------------------------------
# 13. Dock current layout
# ---------------------------------

log "Capturing current Dock layout..."
if command -v dockutil &> /dev/null; then
  dockutil --list > "$SNAPSHOT_DIR/dock-layout.txt" 2>/dev/null || echo "Could not list Dock" > "$SNAPSHOT_DIR/dock-layout.txt"
  ok "Dock layout captured."
else
  warn "dockutil not found — skipping Dock layout."
fi

# ---------------------------------
# 14. Git config extras (beyond profile defaults)
# ---------------------------------

log "Capturing git config..."
git config --global --list > "$SNAPSHOT_DIR/gitconfig-full.txt" 2>/dev/null || true
ok "Git config captured."

# ---------------------------------
# 15. NVM
# ---------------------------------

log "Capturing NVM state..."
if command -v nvm &> /dev/null || [ -s "$HOME/.nvm/nvm.sh" ]; then
  {
    echo "current_version=$(source "$HOME/.nvm/nvm.sh" 2>/dev/null && nvm current 2>/dev/null || echo 'unknown')"
    echo "installed_versions:"
    source "$HOME/.nvm/nvm.sh" 2>/dev/null && nvm ls 2>/dev/null || echo "  none"
  } > "$SNAPSHOT_DIR/nvm.txt"
  ok "NVM state captured."
else
  warn "NVM not found — skipping."
fi

# ---------------------------------
# 16. VPN (Surfshark)
# ---------------------------------

log "Checking Surfshark configuration..."
if [ -d "$HOME/Library/Application Support/com.surfshark.vpnclient.macos" ]; then
  ok "Surfshark config found — use scripts/backup-licenses.sh to back it up separately."
else
  warn "Surfshark config not found."
fi

# ---------------------------------
# Summary
# ---------------------------------

SNAPSHOT_DATE=$(date '+%Y-%m-%d %H:%M:%S')
echo "$SNAPSHOT_DATE" > "$SNAPSHOT_DIR/snapshot-date.txt"

echo ""
echo "================================================"
ok "Snapshot complete! Saved to: $SNAPSHOT_DIR"
echo "  Machine ID: $MACHINE_ID"
echo "================================================"
echo ""
echo "  Next: review the files, then commit if you want to save this snapshot:"
echo "    cd $DOTFILES_DIR"
echo "    git add snapshots/"
echo "    git commit -m 'chore: update system snapshot'"
echo "    git push origin main"
echo ""
