#!/usr/bin/env bash

echo "Configuring macOS..."

# ---------------------------------
# Keyboard
# ---------------------------------

# Faster keyboard repeat
defaults write NSGlobalDomain KeyRepeat -int 2
defaults write NSGlobalDomain InitialKeyRepeat -int 15

# ---------------------------------
# Finder
# ---------------------------------

# Show hidden files
defaults write com.apple.finder AppleShowAllFiles -bool true

# Show path bar
defaults write com.apple.finder ShowPathbar -bool true

# ---------------------------------
# Dock settings (PRO)
# ---------------------------------

echo "Configuring Dock settings..."

# Position (tu configuración actual)
defaults write com.apple.dock orientation -string "left"

# Tamaño (valor por defecto macOS = 48, ajusta si quieres)
defaults write com.apple.dock tilesize -int 48

# Auto-hide (default macOS suele ser false)
defaults write com.apple.dock autohide -bool false

# Animación (valores naturales, no agresivos)
defaults write com.apple.dock autohide-time-modifier -float 0.5
defaults write com.apple.dock autohide-delay -float 0

# Ocultar apps recientes
defaults write com.apple.dock show-recents -bool false

# Restart Finder & Dock to apply settings
killall Finder
killall Dock

# ---------------------------------
# Dock apps (dockutil)
# ---------------------------------

if command -v dockutil &> /dev/null; then
  bash "$HOME/dotfiles/macos/dock.sh"
fi

echo "macOS configuration complete."