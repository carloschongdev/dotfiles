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
  echo ""
  echo "  Select a profile:"
  echo "  [1] personal — single Mac for personal use"
  echo "  [2] work     — single Mac for work only"
  echo "  [3] both     — personal + work on same Mac (default)"
  echo ""
  read -rp "  Profile choice [1/2/3]: " _choice < /dev/tty
  case "${_choice:-3}" in
    1) DOTFILES_PROFILE="personal" ;;
    2) DOTFILES_PROFILE="work" ;;
    *) DOTFILES_PROFILE="both" ;;
  esac
fi

export DOTFILES_PROFILE
log "Using profile: $DOTFILES_PROFILE"
source "$DOTFILES_DIR/profiles/$DOTFILES_PROFILE.sh"

# ---------------------------------
# Generate profile-specific config files
# ---------------------------------

log "Generating profile-specific config files..."

cp "$DOTFILES_DIR/profiles/gitconfig-$DOTFILES_PROFILE" "$DOTFILES_DIR/git/.gitconfig"
ok "gitconfig set for profile: $DOTFILES_PROFILE"

if [[ "$DOTFILES_PROFILE" == "both" ]]; then
  cp "$DOTFILES_DIR/zsh/.zshrc-both" "$DOTFILES_DIR/zsh/.zshrc"
else
  cp "$DOTFILES_DIR/zsh/.zshrc-base" "$DOTFILES_DIR/zsh/.zshrc"
fi
ok ".zshrc set for profile: $DOTFILES_PROFILE"

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

log "Checking Brewfile.$DOTFILES_PROFILE packages..."

if brew bundle check --file="$DOTFILES_DIR/Brewfile.$DOTFILES_PROFILE" 2>/dev/null; then
  ok "All Brewfile.$DOTFILES_PROFILE dependencies satisfied."
else
  log "Installing missing Brewfile.$DOTFILES_PROFILE packages..."
  brew bundle --file="$DOTFILES_DIR/Brewfile.$DOTFILES_PROFILE" --no-lock
  ok "Brewfile.$DOTFILES_PROFILE packages installed."
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
