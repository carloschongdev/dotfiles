#!/usr/bin/env bash

# Ask for the administrator password upfront
sudo -v

# Keep sudo alive while the script is running
while true; do
  sudo -n true
  sleep 60
  kill -0 "$$" || exit
done 2>/dev/null &

set -euo pipefail

echo "Starting DevOps machine bootstrap..."

# ---------------------------------
# Install Homebrew if missing
# ---------------------------------

if ! command -v brew &> /dev/null; then
  echo "Installing Homebrew..."

  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

  echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> ~/.zprofile
  eval "$(/opt/homebrew/bin/brew shellenv)"
fi

# ---------------------------------
# Update Homebrew
# ---------------------------------

echo "Updating Homebrew..."
brew update --quiet

# ---------------------------------
# Install Brewfile packages
# ---------------------------------

echo "Checking Brewfile packages..."

if brew bundle check --file="$HOME/dotfiles/Brewfile"; then
  echo "All Brewfile dependencies are satisfied."
else
  echo "Installing missing Brewfile packages..."
  brew bundle --file="$HOME/dotfiles/Brewfile"
fi

# ---------------------------------
# Install Claude Code CLI
# ---------------------------------
echo "Installing Claude Code CLI..."
if ! command -v claude &> /dev/null; then
  curl -fsSL https://claude.ai/install.sh | bash
  echo "Claude Code CLI installed."
else
  echo "Claude Code CLI already installed."
fi

# ---------------------------------
# Setup GitHub SSH
# ---------------------------------

echo "Configuring GitHub SSH..."

SSH_KEY="$HOME/.ssh/id_ed25519"

if [ ! -f "$SSH_KEY" ]; then
  echo "Generating SSH key..."
  ssh-keygen -t ed25519 -C "github" -f "$SSH_KEY" -N ""
else
  echo "SSH key already exists."
fi

# Start ssh-agent
eval "$(ssh-agent -s)"

# Add key to agent
ssh-add "$SSH_KEY" || true

# Ensure ssh config exists
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

echo "GitHub SSH config added."

else
  echo "GitHub SSH config already present."
fi

# ---------------------------------
# Copy public key to clipboard
# ---------------------------------

if command -v pbcopy &> /dev/null; then
  pbcopy < ~/.ssh/id_ed25519.pub
  echo ""
  echo "Your SSH public key has been copied to the clipboard."
else
  echo ""
  echo "Clipboard utility not found. Here is your SSH key:"
  cat ~/.ssh/id_ed25519.pub
fi

echo ""
echo "Add the key to GitHub:"
echo "https://github.com/settings/keys"
echo ""
echo "Just paste it there (Cmd + V)."

# ---------------------------------
# Verify required tools
# ---------------------------------

if ! command -v stow &> /dev/null; then
  echo "Error: GNU Stow is required but not installed."
  echo "Please ensure 'stow' exists in the Brewfile."
  exit 1
fi

# ---------------------------------
# Apply dotfiles with stow
# ---------------------------------

echo "Applying dotfiles..."

cd "$HOME/dotfiles"

for pkg in */ ; do
  pkg=${pkg%/}

  if [[ "$pkg" == "macos" ]]; then
    continue
  fi

  if [[ "$pkg" == ".git" ]]; then
    continue
  fi

  echo "Stowing $pkg..."
  stow -R --adopt "$pkg"

done

# ---------------------------------
# Apply macOS configuration
# ---------------------------------

if [ -f "$HOME/dotfiles/macos/macos.sh" ]; then
  echo "Applying macOS configuration..."
  bash "$HOME/dotfiles/macos/macos.sh"
fi

echo ""
echo "Bootstrap completed successfully!"