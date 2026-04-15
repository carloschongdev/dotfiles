#!/usr/bin/env bash

echo "Configuring Dock..."

# Función segura
add_app() {
  if [ -d "$1" ]; then
    dockutil --add "$1" --no-restart
  else
    echo "Skipping $1 (not installed)"
  fi
}

# Limpiar Dock
dockutil --remove all --no-restart

# ---------------------------------
# System Apps
# ---------------------------------

add_app "/System/Applications/Apps.app"
add_app "/System/Applications/Photos.app"
add_app "/System/Applications/Passwords.app"
add_app "/System/Applications/Notes.app"
add_app "/System/Applications/App Store.app"
add_app "/System/Applications/System Settings.app"
add_app "/System/Applications/iPhone Mirroring.app"

# ---------------------------------
# Microsoft / Work
# ---------------------------------

add_app "/Applications/Microsoft Outlook.app"
add_app "/Applications/Microsoft Teams.app"
add_app "/Applications/Microsoft Excel.app"

# ---------------------------------
# Browsers
# ---------------------------------

add_app "/Applications/Safari.app"
add_app "/Applications/Google Chrome.app"
add_app "/Applications/Brave Browser.app"

# ---------------------------------
# Communication
# ---------------------------------

add_app "/Applications/WhatsApp.app"

# ---------------------------------
# AI / Tools
# ---------------------------------

add_app "/Applications/Claude.app"

# ---------------------------------
# Terminal / Dev
# ---------------------------------

add_app "/System/Applications/Utilities/Terminal.app"
add_app "/Applications/Ghostty.app"
add_app "/Applications/Visual Studio Code.app"
add_app "/Applications/Linear.app"

# ---------------------------------
# Media
# ---------------------------------

add_app "/Applications/Spotify.app"
add_app "/Applications/VLC.app"

# ---------------------------------
# Spacer
# ---------------------------------

dockutil --add '' --type spacer --no-restart

# ---------------------------------
# Downloads Folder
# ---------------------------------

dockutil --add ~/Downloads --view fan --display stack

# Reiniciar Dock
killall Dock

echo "Dock configured!"