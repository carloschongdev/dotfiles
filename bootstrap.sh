#!/bin/bash

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
# Update brew
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

echo "Bootstrap completed successfully!"