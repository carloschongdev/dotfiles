#!/usr/bin/env bash
set -euo pipefail

DOTFILES_DIR="${DOTFILES_DIR:-$HOME/dotfiles}"
source "$DOTFILES_DIR/lib/logging.sh"

log "Configuring SSH for GitHub (personal + work)..."

PERSONAL_KEY="$HOME/.ssh/id_carloschongdev_personal"
WORK_KEY="$HOME/.ssh/id_CarlosChong28_work"

# ---------------------------------
# Create ~/.ssh dir
# ---------------------------------

mkdir -p "$HOME/.ssh"
chmod 700 "$HOME/.ssh"

# ---------------------------------
# Generate keys if they don't exist
# ---------------------------------

if [ ! -f "$PERSONAL_KEY" ]; then
  log "Generating personal SSH key..."
  ssh-keygen -t ed25519 -C "carloschongdev-personal" -f "$PERSONAL_KEY" -N ""
  ok "Personal SSH key generated."
else
  ok "Personal SSH key already exists."
fi

if [ ! -f "$WORK_KEY" ]; then
  log "Generating work SSH key..."
  ssh-keygen -t ed25519 -C "CarlosChong28-work" -f "$WORK_KEY" -N ""
  ok "Work SSH key generated."
else
  ok "Work SSH key already exists."
fi

# ---------------------------------
# Add keys to ssh-agent
# ---------------------------------

eval "$(ssh-agent -s)" > /dev/null
ssh-add "$PERSONAL_KEY" 2>/dev/null || true
ssh-add "$WORK_KEY" 2>/dev/null || true

# ---------------------------------
# Configure ~/.ssh/config
# ---------------------------------

SSH_CONFIG="$HOME/.ssh/config"

if ! grep -q "Host github-work" "$SSH_CONFIG" 2>/dev/null; then
  cat >> "$SSH_CONFIG" <<EOF

# =========================
# WORK (InTech)
# =========================
Host github-work
  HostName github.com
  User git
  IdentityFile $HOME/.ssh/id_CarlosChong28_work
  AddKeysToAgent yes
  UseKeychain yes
EOF
  ok "Work SSH config added."
else
  ok "Work SSH config already present."
fi

if ! grep -q "Host github-personal" "$SSH_CONFIG" 2>/dev/null; then
  cat >> "$SSH_CONFIG" <<EOF

# =========================
# PERSONAL
# =========================
Host github-personal
  HostName github.com
  User git
  IdentityFile $HOME/.ssh/id_carloschongdev_personal
  AddKeysToAgent yes
  UseKeychain yes
EOF
  ok "Personal SSH config added."
else
  ok "Personal SSH config already present."
fi

chmod 600 "$SSH_CONFIG"

# ---------------------------------
# Show public keys for GitHub
# ---------------------------------

echo ""
log "Add the following public keys to GitHub (https://github.com/settings/keys):"
echo ""
warn "── PERSONAL (carloschongdev) ──"
cat "$PERSONAL_KEY.pub"
echo ""
warn "── WORK (CarlosChong28) ──"
cat "$WORK_KEY.pub"
