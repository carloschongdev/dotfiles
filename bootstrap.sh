#!/usr/bin/env bash
set -euo pipefail

DOTFILES_DIR="$HOME/dotfiles"

source "$DOTFILES_DIR/lib/logging.sh"

# Progress tracking
TOTAL_STEPS=10
CURRENT_STEP=0

step() {
  CURRENT_STEP=$((CURRENT_STEP + 1))
  echo ""
  echo "────────────────────────────────────────"
  echo "  Step $CURRENT_STEP/$TOTAL_STEPS — $1"
  echo "────────────────────────────────────────"
}

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

step "Detecting profile"

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
# Step selector — choose steps to skip
# ---------------------------------

echo ""
echo "  Skip any steps? Enter numbers separated by commas, or press Enter for none."
echo ""
echo "  [1] macOS config    — dark mode, wallpaper, resolution, dock settings"
echo "  [2] SSH setup       — generate SSH keys and configure GitHub hosts"
echo "  [3] Brewfile apps   — install all brew/cask packages"
echo "  [4] App Store apps  — install mas apps (requires Apple ID auth per app)"
echo "  [5] Dock layout     — arrange app icons in the Dock"
echo "  [6] Claude CLI      — install Claude Code command line tool"
echo ""
read -rp "  Steps to skip [none]: " SKIP_STEPS < /dev/tty

# Parse skip steps into array
SKIP=()
if [ -n "$SKIP_STEPS" ]; then
  IFS=',' read -ra SKIP <<< "$SKIP_STEPS"
fi

should_skip() {
  local step="$1"
  for s in "${SKIP[@]}"; do
    s="${s// /}"  # trim spaces
    [[ "$s" == "$step" ]] && return 0
  done
  return 1
}

# ---------------------------------
# Install Homebrew if missing
# ---------------------------------

step "Installing Homebrew"

if ! command -v brew &> /dev/null; then
  log "Installing Homebrew..."
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> ~/.zprofile
  eval "$(/opt/homebrew/bin/brew shellenv)"
  ok "Homebrew installed."
else
  ok "Homebrew already installed."
fi

log "Updating Homebrew..."
brew update --quiet

# ---------------------------------
# Apply dotfiles with stow
# ---------------------------------

step "Installing GNU Stow"

if ! command -v stow &> /dev/null; then
  log "Installing GNU Stow..."
  brew install stow --quiet
  ok "GNU Stow installed."
else
  ok "GNU Stow already installed."
fi

step "Applying dotfiles"

log "Applying dotfiles..."

# Create .config subdirectories before stow to ensure symlinks are created correctly
log "Preparing .config directories..."
mkdir -p "$HOME/.config/ghostty"
mkdir -p "$HOME/.config/fastfetch"
mkdir -p "$HOME/.config/starship"
ok ".config directories ready."

cd "$DOTFILES_DIR"

# Directories that are not stow packages
_NO_STOW=("macos" "lib" "profiles" "docs" "scripts")

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
# Install displayplacer early (needed for resolution config)
# ---------------------------------

step "Configuring display resolution"

if ! command -v displayplacer &> /dev/null; then
  log "Installing displayplacer for display configuration..."
  brew install displayplacer --quiet
  ok "displayplacer installed."
else
  ok "displayplacer already installed."
fi

# ---------------------------------
# Apply macOS configuration
# ---------------------------------

step "Configuring macOS"

if should_skip 1; then
  warn "Skipping macOS configuration."
else
  if [[ -f "$DOTFILES_DIR/macos/macos.sh" ]]; then
    log "Applying macOS configuration..."
    DOTFILES_DIR="$DOTFILES_DIR" bash "$DOTFILES_DIR/macos/macos.sh"
  fi
fi

# ---------------------------------
# Setup GitHub SSH
# ---------------------------------

step "Configuring SSH"

if should_skip 2; then
  warn "Skipping SSH setup."
else
  DOTFILES_DIR="$DOTFILES_DIR" DOTFILES_PROFILE="$DOTFILES_PROFILE" bash "$DOTFILES_DIR/ssh/setup_ssh.sh"
fi

# ---------------------------------
# Install Brewfile packages (with retry, excluding mas)
# ---------------------------------

step "Installing packages"

if should_skip 3; then
  warn "Skipping Brewfile packages."
else
  log "Checking Brewfile.$DOTFILES_PROFILE packages..."

  grep -v "^mas " "$DOTFILES_DIR/Brewfile.$DOTFILES_PROFILE" > /tmp/Brewfile.nocask.tmp

  MAX_ATTEMPTS=3
  ATTEMPT=1

  while [ $ATTEMPT -le $MAX_ATTEMPTS ]; do
    if brew bundle check --file="/tmp/Brewfile.nocask.tmp" 2>/dev/null; then
      ok "All brew/cask dependencies satisfied."
      break
    else
      log "Installing brew/cask packages (attempt $ATTEMPT/$MAX_ATTEMPTS)..."
      if brew bundle --file="/tmp/Brewfile.nocask.tmp"; then
        ok "brew/cask packages installed."
        break
      else
        if [ $ATTEMPT -lt $MAX_ATTEMPTS ]; then
          warn "Some packages failed — retrying in 5 seconds... ($ATTEMPT/$MAX_ATTEMPTS)"
          sleep 5
        else
          warn "Some packages failed after $MAX_ATTEMPTS attempts."
          warn "To retry: brew bundle --file=$DOTFILES_DIR/Brewfile.$DOTFILES_PROFILE"
        fi
      fi
    fi
    ATTEMPT=$((ATTEMPT + 1))
  done

  rm -f /tmp/Brewfile.nocask.tmp
fi

# ---------------------------------
# Install mas apps (App Store) with confirmation
# ---------------------------------

if should_skip 4 || should_skip 3; then
  warn "Skipping App Store apps."
else
  log "Checking App Store apps..."

  MAS_APPS=$(grep "^mas " "$DOTFILES_DIR/Brewfile.$DOTFILES_PROFILE" | sed 's/mas "\(.*\)", id:.*/\1/')

  if [ -n "$MAS_APPS" ]; then
    echo ""
    echo "  The following App Store apps will be installed:"
    echo ""
    echo "$MAS_APPS" | while read -r app; do
      echo "    - $app"
    done
    echo ""
    read -rp "  Install App Store apps? (Y/n): " mas_confirm < /dev/tty

    if [[ "$mas_confirm" != "n" && "$mas_confirm" != "N" ]]; then
      log "Installing App Store apps..."
      grep "^mas " "$DOTFILES_DIR/Brewfile.$DOTFILES_PROFILE" > /tmp/Brewfile.mas.tmp
      if brew bundle --file=/tmp/Brewfile.mas.tmp; then
        ok "App Store apps installed."
      else
        warn "Some App Store apps failed — install manually from the App Store."
      fi
      rm -f /tmp/Brewfile.mas.tmp
    else
      warn "Skipping App Store apps — install manually from the App Store when ready."
    fi
  else
    ok "No App Store apps in this profile."
  fi
fi

# ---------------------------------
# Dock layout
# ---------------------------------

step "Configuring Dock"

if should_skip 5; then
  warn "Skipping Dock layout."
else
  if command -v dockutil &> /dev/null; then
    log "Configuring Dock layout..."
    case "${DOTFILES_PROFILE:-both}" in
      personal) bash "$DOTFILES_DIR/macos/dock-personal.sh" ;;
      work)     bash "$DOTFILES_DIR/macos/dock-work.sh" ;;
      *)        bash "$DOTFILES_DIR/macos/dock-both.sh" ;;
    esac
  else
    warn "dockutil not found — skipping Dock layout."
  fi
fi

# ---------------------------------
# Install Claude Code CLI
# ---------------------------------

step "Installing Claude Code CLI"

if should_skip 6; then
  warn "Skipping Claude Code CLI installation."
else
  if ! command -v claude &> /dev/null; then
    log "Installing Claude Code CLI..."
    curl -fsSL https://claude.ai/install.sh | bash
    ok "Claude Code CLI installed."
  else
    ok "Claude Code CLI already installed."
  fi
fi

# ---------------------------------
# Bootstrap summary
# ---------------------------------

ACTIVE_GH=$(gh auth status 2>/dev/null | grep "Active account: true" -B1 | grep "Logged" | awk '{print $7}' || true)

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
