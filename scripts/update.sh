#!/usr/bin/env bash
set -euo pipefail

DOTFILES_DIR="${DOTFILES_DIR:-$HOME/dotfiles}"
source "$DOTFILES_DIR/lib/logging.sh"

log "Updating dotfiles and system..."

# ---------------------------------
# 1. Pull latest dotfiles
# ---------------------------------

log "Pulling latest dotfiles from GitHub..."
cd "$DOTFILES_DIR"
git pull --rebase origin main
ok "Dotfiles up to date."

# ---------------------------------
# 2. Re-apply stow
# ---------------------------------

log "Re-applying stow..."
cd "$DOTFILES_DIR"

_NO_STOW=("macos" "lib" "profiles" "docs" "scripts")

for pkg in */; do
  pkg="${pkg%/}"
  skip=false
  for s in "${_NO_STOW[@]}"; do
    [[ "$pkg" == "$s" ]] && skip=true && break
  done
  $skip && continue
  stow -R --adopt "$pkg" 2>/dev/null || true
done
ok "Stow re-applied."

# ---------------------------------
# 3. Update Homebrew
# ---------------------------------

log "Updating Homebrew..."
brew update --quiet
ok "Homebrew updated."

# ---------------------------------
# 4. Upgrade packages
# ---------------------------------

log "Upgrading packages..."
brew upgrade --quiet
ok "Packages upgraded."

# ---------------------------------
# 5. Cleanup
# ---------------------------------

log "Cleaning up..."
brew autoremove --quiet
brew cleanup --quiet
ok "Cleanup complete."

# ---------------------------------
# 6. Run verify
# ---------------------------------

echo ""
log "Running health check..."
bash "$DOTFILES_DIR/scripts/verify.sh"
