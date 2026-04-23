#!/usr/bin/env bash
set -euo pipefail

DOTFILES_DIR="${DOTFILES_DIR:-$HOME/dotfiles}"
source "$DOTFILES_DIR/lib/logging.sh"

log "Configuring SSH for GitHub..."

SSH_KEY="$HOME/.ssh/id_ed25519"

# ---------------------------------
# Create SSH key if it doesn't exist
# ---------------------------------

mkdir -p ~/.ssh
chmod 700 ~/.ssh

if [ ! -f "$SSH_KEY" ]; then
  log "Generating SSH key..."
  ssh-keygen -t ed25519 -C "github" -f "$SSH_KEY" -N ""
  ok "SSH key generated."
else
  ok "SSH key already exists."
fi

# ---------------------------------
# Start ssh-agent and add key
# ---------------------------------

eval "$(ssh-agent -s)" > /dev/null
ssh-add "$SSH_KEY" 2>/dev/null || true

# ---------------------------------
# Add GitHub host to ssh config
# ---------------------------------

SSH_CONFIG="$HOME/.ssh/config"

if ! grep -q "Host github.com" "$SSH_CONFIG" 2>/dev/null; then
  cat >> "$SSH_CONFIG" <<EOF

Host github.com
  HostName github.com
  User git
  IdentityFile ~/.ssh/id_ed25519
  AddKeysToAgent yes
  UseKeychain yes
EOF
  ok "GitHub SSH config added."
else
  ok "GitHub SSH config already present."
fi

chmod 600 "$SSH_CONFIG"

# ---------------------------------
# Copy public key to clipboard
# ---------------------------------

echo ""
if command -v pbcopy &> /dev/null; then
  pbcopy < "$SSH_KEY.pub"
  ok "SSH public key copied to clipboard."
else
  warn "pbcopy not found — printing key instead:"
  cat "$SSH_KEY.pub"
fi

log "Add the key at: https://github.com/settings/keys"
