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
# Apply dotfiles with stow
# ---------------------------------

if ! command -v stow &> /dev/null; then
  log "Installing GNU Stow..."
  brew install stow --quiet
  ok "GNU Stow installed."
fi

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

# ---------------------------------
# Setup GitHub SSH
# ---------------------------------

DOTFILES_DIR="$DOTFILES_DIR" DOTFILES_PROFILE="$DOTFILES_PROFILE" bash "$DOTFILES_DIR/ssh/setup_ssh.sh"

# ---------------------------------
# Install Brewfile packages
# ---------------------------------

log "Checking Brewfile.$DOTFILES_PROFILE packages..."

if brew bundle check --file="$DOTFILES_DIR/Brewfile.$DOTFILES_PROFILE" 2>/dev/null; then
  ok "All Brewfile.$DOTFILES_PROFILE dependencies satisfied."
else
  log "Installing missing Brewfile.$DOTFILES_PROFILE packages..."
  brew bundle --file="$DOTFILES_DIR/Brewfile.$DOTFILES_PROFILE"
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
# Display resolution
# ---------------------------------

if command -v displayplacer &> /dev/null; then
  log "Configuring display resolution..."
  MODEL=$(system_profiler SPHardwareDataType 2>/dev/null | grep "Model Name" | awk -F: '{print $2}' | xargs)
  SCREEN_ID=$(displayplacer list 2>/dev/null | grep "Persistent screen id" | awk '{print $4}' | head -1)

  if [ -n "$SCREEN_ID" ]; then
    case "$MODEL" in
      *"MacBook Air"*)
        CHIP=$(sysctl -n machdep.cpu.brand_string 2>/dev/null)
        if echo "$CHIP" | grep -qE "M3|M4"; then
          displayplacer "id:$SCREEN_ID mode:11" 2>/dev/null && ok "Resolution set to 2048x1332 (Air M3/M4)." || warn "Could not set resolution."
        else
          displayplacer "id:$SCREEN_ID mode:11" 2>/dev/null && ok "Resolution set to 2048x1332 (Air M1/M2)." || warn "Could not set resolution."
        fi
        ;;
      *"MacBook Pro"*)
        SCREEN_WIDTH=$(displayplacer list 2>/dev/null | grep "Resolution:" | head -1 | grep -o '[0-9]*x' | head -1 | tr -d 'x')
        if [ "${SCREEN_WIDTH:-0}" -ge 3400 ]; then
          displayplacer "id:$SCREEN_ID mode:11" 2>/dev/null && ok "Resolution set (Pro 16\")." || warn "Could not set resolution."
        else
          displayplacer "id:$SCREEN_ID mode:11" 2>/dev/null && ok "Resolution set (Pro 14\")." || warn "Could not set resolution."
        fi
        ;;
      *)
        warn "Unknown model '$MODEL' — skipping resolution config."
        ;;
    esac
  else
    warn "Could not detect screen ID — skipping resolution config."
  fi
else
  warn "displayplacer not found — skipping resolution config."
fi

# ---------------------------------
# Bootstrap summary
# ---------------------------------

ACTIVE_GH=$(gh auth status 2>/dev/null | grep "Active account: true" -B1 | grep "Logged" | awk '{print $7}')

echo ""
echo "================================================"
echo "  BOOTSTRAP COMPLETE"
echo "================================================"
echo "  Profile  : $DOTFILES_PROFILE"
echo "  Git email: $PROFILE_GIT_EMAIL"
echo "  SSH keys : ${PROFILE_SSH_KEYS[*]}"
echo "  gh user  : ${ACTIVE_GH:-not detected}"
echo "  Hostname : $(hostname)"
echo "  Date     : $(date '+%Y-%m-%d %H:%M:%S')"
echo "================================================"
echo ""
echo "  Next steps:"
echo "  1. Add SSH public keys to GitHub:"
echo "     https://github.com/settings/keys"
echo ""
for key_name in "${PROFILE_SSH_KEYS[@]}"; do
  echo "  ── $key_name ──"
  cat "$HOME/.ssh/$key_name.pub" 2>/dev/null || echo "  Key not found: $key_name"
  echo ""
done
echo "  2. Run: gh auth login"
echo "  3. Verify: ssh -T git@github.com"
echo ""
echo "================================================"
echo ""
