#!/usr/bin/env bash
set -euo pipefail

echo "Starting DevOps workstation setup..."

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
# Install Git if missing
# ---------------------------------

if ! command -v git &> /dev/null; then
  echo "Installing Git..."
  brew install git
fi

# ---------------------------------
# Clone dotfiles repo
# ---------------------------------

if [ ! -d "$HOME/dotfiles" ]; then
  echo "Cloning dotfiles..."
  git clone https://github.com/carloschongdev/dotfiles.git "$HOME/dotfiles"
else
  echo "Dotfiles repo already exists — pulling latest changes..."
  git -C "$HOME/dotfiles" pull --rebase origin main 2>/dev/null || {
    echo "Could not pull latest changes — continuing with local version."
  }
fi

# ---------------------------------
# Run bootstrap
# ---------------------------------

echo "Running bootstrap..."
bash "$HOME/dotfiles/bootstrap.sh"

echo "DevOps workstation ready!"
