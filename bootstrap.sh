#!/bin/bash

echo "Installing Homebrew..."

if ! command -v brew &> /dev/null
then
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
fi

echo "Installing CLI tools..."

brew install git
brew install kubectl
brew install starship
brew install fastfetch

echo "Installing applications..."

brew install --cask ghostty
brew install --cask docker
brew install --cask font-jetbrains-mono-nerd-font

echo "Creating config directories..."

mkdir -p ~/.config/ghostty
mkdir -p ~/.config/fastfetch

echo "Copying dotfiles..."

cp .zshrc ~/.zshrc
cp ghostty/config ~/.config/ghostty/config
cp fastfetch/config.jsonc ~/.config/fastfetch/config.jsonc

echo "Bootstrap complete!"
