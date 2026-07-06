#!/usr/bin/env bash
set -euo pipefail

DOTFILES_DIR="${DOTFILES_DIR:-$HOME/dotfiles}"
source "$DOTFILES_DIR/lib/logging.sh"

SNAPSHOTS_ROOT="$DOTFILES_DIR/snapshots"

if [ ! -d "$SNAPSHOTS_ROOT" ] || [ -z "$(ls -A "$SNAPSHOTS_ROOT" 2>/dev/null)" ]; then
  error "No snapshots found in $SNAPSHOTS_ROOT. Run scripts/snapshot.sh on a source machine first."
  exit 1
fi

echo ""
echo "================================================"
echo "  DOTFILES RESTORE"
echo "================================================"
echo ""
echo "  Available snapshots:"
echo ""

mapfile -t SNAPSHOT_LIST < <(ls -1 "$SNAPSHOTS_ROOT")

if [ ${#SNAPSHOT_LIST[@]} -eq 0 ]; then
  error "No snapshots available."
  exit 1
fi

for i in "${!SNAPSHOT_LIST[@]}"; do
  SNAP_NAME="${SNAPSHOT_LIST[$i]}"
  SNAP_DATE=$(cat "$SNAPSHOTS_ROOT/$SNAP_NAME/snapshot-date.txt" 2>/dev/null || echo "unknown date")
  # Extract machine ID without the timestamp suffix for cleaner display
  MACHINE_LABEL=$(echo "$SNAP_NAME" | sed -E 's/-[0-9]{8}-[0-9]{6}$//')
  echo "  [$((i+1))] $MACHINE_LABEL — $SNAP_DATE"
done

echo ""
read -rp "  Select snapshot to restore [1-${#SNAPSHOT_LIST[@]}]: " snap_choice < /dev/tty || true

if [[ ! "$snap_choice" =~ ^[0-9]+$ ]] || [ "$snap_choice" -lt 1 ] || [ "$snap_choice" -gt ${#SNAPSHOT_LIST[@]} ]; then
  error "Invalid selection."
  exit 1
fi

SELECTED_SNAPSHOT="${SNAPSHOT_LIST[$((snap_choice-1))]}"
SNAPSHOT_DIR="$SNAPSHOTS_ROOT/$SELECTED_SNAPSHOT"

echo ""
ok "Restoring from: $SELECTED_SNAPSHOT"
echo "  Snapshot date: $(cat "$SNAPSHOT_DIR/snapshot-date.txt" 2>/dev/null || echo 'unknown')"
echo ""

RESTORED=()
PARTIAL=()
FAILED=()

# ---------------------------------
# 1. Apply overrides
# ---------------------------------

log "Applying detected overrides..."
if [ -s "$SNAPSHOT_DIR/overrides.txt" ]; then
  while IFS='|' read -r domain key value description; do
    if defaults write "$domain" "$key" "$value" 2>/dev/null; then
      RESTORED+=("Override: $description ($value)")
    else
      FAILED+=("Override: $description — could not apply")
    fi
  done < "$SNAPSHOT_DIR/overrides.txt"
else
  ok "No overrides to apply — system will use bootstrap defaults."
fi

# ---------------------------------
# 2. Display resolution
# ---------------------------------

log "Restoring display resolution..."
if [ -f "$SNAPSHOT_DIR/resolution-mode.txt" ] && command -v displayplacer &> /dev/null; then
  MODE=$(grep -o "mode [0-9]*" "$SNAPSHOT_DIR/resolution-mode.txt" | head -1 | awk '{print $2}')
  SCREEN_ID=$(displayplacer list 2>/dev/null | grep "Persistent screen id" | awk '{print $4}' | head -1)
  if [ -n "$MODE" ] && [ -n "$SCREEN_ID" ]; then
    if displayplacer "id:$SCREEN_ID mode:$MODE" 2>/dev/null; then
      RESTORED+=("Display resolution (mode $MODE)")
    else
      PARTIAL+=("Display resolution — mode $MODE not available on this display, apply manually")
    fi
  fi
else
  PARTIAL+=("Display resolution — no snapshot data or displayplacer missing")
fi

# ---------------------------------
# 3. Login Items
# ---------------------------------

if [ -f "$SNAPSHOT_DIR/login-items.txt" ]; then
  PARTIAL+=("Login Items — list saved at snapshots/LATEST/login-items.txt, must be added manually via System Settings > General > Login Items (macOS does not allow programmatic restoration)")
fi

# ---------------------------------
# 4. Launch Agents
# ---------------------------------

if [ -f "$SNAPSHOT_DIR/launch-agents.txt" ] && [ -s "$SNAPSHOT_DIR/launch-agents.txt" ]; then
  PARTIAL+=("Launch Agents — list saved at snapshots/LATEST/launch-agents.txt, agents will be recreated automatically if their apps are reinstalled and configured to launch at login")
fi

# ---------------------------------
# 5. Brewfile snapshot
# ---------------------------------

log "Checking Brewfile snapshot..."
if [ -f "$SNAPSHOT_DIR/Brewfile.snapshot" ]; then
  echo ""
  read -rp "  Install all apps from the snapshot Brewfile? (y/N): " install_confirm < /dev/tty || true
  if [[ "$install_confirm" == "y" || "$install_confirm" == "Y" ]]; then
    if brew bundle --file="$SNAPSHOT_DIR/Brewfile.snapshot"; then
      RESTORED+=("Apps from Brewfile snapshot")
    else
      PARTIAL+=("Some apps from Brewfile snapshot failed to install")
    fi
  else
    PARTIAL+=("Brewfile snapshot skipped by user — install manually with: brew bundle --file=$SNAPSHOT_DIR/Brewfile.snapshot")
  fi
else
  FAILED+=("No Brewfile snapshot found")
fi

# ---------------------------------
# 6. App Store apps
# ---------------------------------

if [ -f "$SNAPSHOT_DIR/mas-apps.txt" ] && [ -s "$SNAPSHOT_DIR/mas-apps.txt" ]; then
  PARTIAL+=("App Store apps — list saved at snapshots/LATEST/mas-apps.txt, install manually or via mas install <id>")
fi

# ---------------------------------
# 7. VS Code extensions
# ---------------------------------

log "Restoring VS Code extensions..."
if [ -f "$SNAPSHOT_DIR/vscode-extensions.txt" ] && command -v code &> /dev/null; then
  while read -r ext; do
    code --install-extension "$ext" &> /dev/null && RESTORED+=("VS Code extension: $ext") || FAILED+=("VS Code extension: $ext")
  done < "$SNAPSHOT_DIR/vscode-extensions.txt"
else
  PARTIAL+=("VS Code extensions — no snapshot or VS Code CLI not available")
fi

# ---------------------------------
# 8. Dock layout
# ---------------------------------

if [ -f "$SNAPSHOT_DIR/dock-layout.txt" ]; then
  PARTIAL+=("Dock layout — reference saved at snapshots/LATEST/dock-layout.txt. The profile's dock-*.sh script will configure the standard layout; manual apps must be re-added")
fi

# ---------------------------------
# 9. Trackpad, mouse, keyboard, sound, accessibility
# ---------------------------------

for f in trackpad-mouse keyboard sound accessibility; do
  if [ -f "$SNAPSHOT_DIR/$f.txt" ]; then
    PARTIAL+=("$f settings — reference saved at snapshots/LATEST/$f.txt, review and apply manually if different from current")
  fi
done

# ---------------------------------
# 10. WiFi networks
# ---------------------------------

if [ -f "$SNAPSHOT_DIR/wifi-networks.txt" ]; then
  PARTIAL+=("WiFi networks — names saved at snapshots/LATEST/wifi-networks.txt, passwords must be re-entered manually (not exportable from Keychain)")
fi

# ---------------------------------
# 11. Energy settings
# ---------------------------------

if [ -f "$SNAPSHOT_DIR/pmset.txt" ]; then
  PARTIAL+=("Energy settings — reference saved at snapshots/LATEST/pmset.txt, bootstrap already sets display sleep; review other settings manually")
fi

# ---------------------------------
# Report
# ---------------------------------

echo ""
echo "================================================"
echo "  RESTORE REPORT"
echo "================================================"
echo ""

if [ ${#RESTORED[@]} -gt 0 ]; then
  echo "  ✓ Fully restored:"
  for item in "${RESTORED[@]}"; do
    echo "      - $item"
  done
  echo ""
fi

if [ ${#PARTIAL[@]} -gt 0 ]; then
  echo "  ⚠ Partially restored / needs manual action:"
  for item in "${PARTIAL[@]}"; do
    echo "      - $item"
  done
  echo ""
fi

if [ ${#FAILED[@]} -gt 0 ]; then
  echo "  ✗ Could not restore:"
  for item in "${FAILED[@]}"; do
    echo "      - $item"
  done
  echo ""
fi

echo "================================================"
echo ""
