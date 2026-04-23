#!/usr/bin/env bash
set -euo pipefail

DOTFILES_DIR="$HOME/dotfiles"

source "$DOTFILES_DIR/lib/logging.sh"

# Ask for the administrator password upfront and keep it alive
sudo -v
while true; do
  sudo -n true
  sleep 60
  kill -0 "$$" || exit
done 2>/dev/null &

log "Starting DevOps machine bootstrap..."

# ---------------------------------
# Profile detection
# ---------------------------------

if [[ -z "${DOTFILES_PROFILE:-}" ]]; then
  log "Select a profile:"
  log "  [1] personal (default)"
  log "  [2] work"
  read -r -p "Profile choice [1/2]: " _choice
  case "${_choice:-1}" in
    2) DOTFILES_PROFILE="work" ;;
    *) DOTFILES_PROFILE="personal" ;;
  esac
fi

export DOTFILES_PROFILE
log "Using profile: $DOTFILES_PROFILE"
source "$DOTFILES_DIR/profiles/$DOTFILES_PROFILE.sh"

# ---------------------------------
# Install Homebrew if missing
# ---------------------------------

if ! command -v brew &> /dev/null; then
  log "Installing Homebrew..."
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> ~/.zprofile
  eval "$(/opt/homebrew/bin/brew shellenv)"
  ok "Homebrew installed."
else
  ok "Homebrew already installed."
fi

# ---------------------------------
# Update Homebrew
# ---------------------------------

log "Updating Homebrew..."
brew update --quiet

# ---------------------------------
# Install Brewfile packages
# ---------------------------------

log "Checking Brewfile packages..."

if brew bundle check --file="$DOTFILES_DIR/Brewfile" 2>/dev/null; then
  ok "All Brewfile dependencies satisfied."
else
  log "Installing missing Brewfile packages..."
  brew bundle --file="$DOTFILES_DIR/Brewfile" --no-lock
  ok "Brewfile packages installed."
fi

# ---------------------------------
# Install Claude Code CLI
# ---------------------------------

if ! command -v claude &> /dev/null; then
  log "Installing Claude Code CLI..."
  curl -fsSL https://claude.ai/install.sh | bash
  ok "Claude Code CLI installed."
else
  ok "Claude Code CLI already installed."
fi

# ---------------------------------
# Setup GitHub SSH
# ---------------------------------

DOTFILES_DIR="$DOTFILES_DIR" bash "$DOTFILES_DIR/ssh/setup_ssh.sh"

# ---------------------------------
# Verify required tools
# ---------------------------------

if ! command -v stow &> /dev/null; then
  error "GNU Stow is required but not installed. Ensure 'stow' is in the Brewfile."
  exit 1
fi

# ---------------------------------
# Apply dotfiles with stow
# ---------------------------------

log "Applying dotfiles..."

cd "$DOTFILES_DIR"

# Directories that are not stow packages
_NO_STOW=("macos" "lib" "profiles" "docs")

for pkg in */ ; do
  pkg="${pkg%/}"

  skip=false
  for s in "${_NO_STOW[@]}"; do
    [[ "$pkg" == "$s" ]] && skip=true && break
  done
  $skip && continue

  log "Stowing $pkg..."
  stow -R --adopt "$pkg"
done

ok "Dotfiles applied."

# ---------------------------------
# Apply macOS configuration
# ---------------------------------

if [[ -f "$DOTFILES_DIR/macos/macos.sh" ]]; then
  log "Applying macOS configuration..."
  DOTFILES_DIR="$DOTFILES_DIR" bash "$DOTFILES_DIR/macos/macos.sh"
fi

ok "Bootstrap completed successfully!"
