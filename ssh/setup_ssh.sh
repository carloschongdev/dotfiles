#!/bin/bash

set -e

echo "Configuring SSH for GitHub..."

SSH_KEY="$HOME/.ssh/id_ed25519"

# ---------------------------------
# Create SSH key if it doesn't exist
# ---------------------------------

if [ ! -f "$SSH_KEY" ]; then
  echo "Generating SSH key..."

  ssh-keygen -t ed25519 -C "github" -f "$SSH_KEY" -N ""
else
  echo "SSH key already exists."
fi

# ---------------------------------
# Start ssh-agent
# ---------------------------------

eval "$(ssh-agent -s)"

# ---------------------------------
# Add key to agent
# ---------------------------------

ssh-add "$SSH_KEY" || true

# ---------------------------------
# Create ssh config if missing
# ---------------------------------

mkdir -p ~/.ssh

SSH_CONFIG="$HOME/.ssh/config"

if ! grep -q "github.com" "$SSH_CONFIG" 2>/dev/null; then

cat <<EOF >> "$SSH_CONFIG"

Host github.com
  HostName github.com
  User git
  IdentityFile ~/.ssh/id_ed25519
  AddKeysToAgent yes
  UseKeychain yes

EOF

echo "SSH config for GitHub added."

else
  echo "SSH config already present."
fi

# ---------------------------------
# Print public key
# ---------------------------------

echo ""
echo "Add this key to GitHub:"
echo "https://github.com/settings/keys"
echo ""

cat ~/.ssh/id_ed25519.pub