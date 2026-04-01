#!/bin/bash

echo "Installing Homebrew..."

if ! command -v brew &> /dev/null
then
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
fi

echo "Updating Homebrew..."
brew update

echo "Installing packages from Brewfile..."
brew bundle --file=~/dotfiles/Brewfile

echo "Creating config directories..."

mkdir -p ~/.config/ghostty
mkdir -p ~/.config/fastfetch

echo "Copying dotfiles..."

cp .zshrc ~/.zshrc
cp ghostty/config ~/.config/ghostty/config
cp fastfetch/config.jsonc ~/.config/fastfetch/config.jsonc

echo "Bootstrap complete!"
