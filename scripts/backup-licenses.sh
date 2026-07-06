#!/usr/bin/env bash
set -euo pipefail

DOTFILES_DIR="${DOTFILES_DIR:-$HOME/dotfiles}"
source "$DOTFILES_DIR/lib/logging.sh"

BACKUP_DIR="$DOTFILES_DIR/backups/licenses"
mkdir -p "$BACKUP_DIR"

log "Backing up known app licenses..."

# ---------------------------------
# Surfshark
# ---------------------------------

SURFSHARK_PATH="$HOME/Library/Application Support/com.surfshark.vpnclient.macos"
if [ -d "$SURFSHARK_PATH" ]; then
  cp -R "$SURFSHARK_PATH" "$BACKUP_DIR/surfshark-$(date +%Y%m%d)" 2>/dev/null || true
  ok "Surfshark config backed up."
else
  warn "Surfshark config not found — skipping."
fi

# ---------------------------------
# Generic license file detection
# ---------------------------------

log "Scanning for other potential license files..."

FOUND_LICENSES=$(find "$HOME/Library/Application Support" -maxdepth 2 \( -iname "*license*" -o -iname "*.key" -o -iname "*activation*" \) 2>/dev/null || true)

if [ -n "$FOUND_LICENSES" ]; then
  echo ""
  echo "  Found potential license files (not backed up automatically):"
  echo ""
  echo "$FOUND_LICENSES" | while read -r f; do
    echo "    - $f"
  done
  echo ""
  warn "Review these manually — add them to backup-licenses.sh if needed."
else
  ok "No additional license files detected."
fi

ok "License backup complete. Files saved to: $BACKUP_DIR"
