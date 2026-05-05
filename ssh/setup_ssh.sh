#!/usr/bin/env bash
set -euo pipefail

DOTFILES_DIR="${DOTFILES_DIR:-$HOME/dotfiles}"
source "$DOTFILES_DIR/lib/logging.sh"

DRY_RUN=false
[[ "${1:-}" == "--dry-run" ]] && DRY_RUN=true

: "${DOTFILES_PROFILE:?DOTFILES_PROFILE not set — export DOTFILES_PROFILE before running this script}"

PERSONAL_KEY="id_carloschongdev_personal"
WORK_KEY="id_CarlosChong28_work"

case "$DOTFILES_PROFILE" in
  personal) SSH_KEYS=("$PERSONAL_KEY") ;;
  work)     SSH_KEYS=("$WORK_KEY") ;;
  both)     SSH_KEYS=("$PERSONAL_KEY" "$WORK_KEY") ;;
  *) echo "Unknown profile: $DOTFILES_PROFILE"; exit 1 ;;
esac

# ---------------------------------
# Dry-run: print plan and exit
# ---------------------------------

if $DRY_RUN; then
  echo ""
  echo "Profile: $DOTFILES_PROFILE"
  echo "Keys to generate:"
  for k in "${SSH_KEYS[@]}"; do echo "  ~/.ssh/$k"; done
  echo ""
  echo "~/.ssh/config Host block:"
  echo ""
  case "$DOTFILES_PROFILE" in
    personal)
      cat <<EOF
Host github.com
  HostName github.com
  User git
  IdentityFile ~/.ssh/$PERSONAL_KEY
  AddKeysToAgent yes
  UseKeychain yes
EOF
      ;;
    work)
      cat <<EOF
Host github.com
  HostName github.com
  User git
  IdentityFile ~/.ssh/$WORK_KEY
  AddKeysToAgent yes
  UseKeychain yes
EOF
      ;;
    both)
      cat <<EOF
Host github.com
  HostName github.com
  User git
  IdentityFile ~/.ssh/$WORK_KEY
  AddKeysToAgent yes
  UseKeychain yes

Host github-work
  HostName github.com
  User git
  IdentityFile ~/.ssh/$WORK_KEY
  AddKeysToAgent yes
  UseKeychain yes

Host github-personal
  HostName github.com
  User git
  IdentityFile ~/.ssh/$PERSONAL_KEY
  AddKeysToAgent yes
  UseKeychain yes
EOF
      ;;
  esac
  exit 0
fi

log "Configuring SSH for profile: $DOTFILES_PROFILE..."

SSH_CONFIG="$HOME/.ssh/config"

# ---------------------------------
# Create ~/.ssh dir
# ---------------------------------

mkdir -p "$HOME/.ssh"
chmod 700 "$HOME/.ssh"

# ---------------------------------
# Generate keys
# ---------------------------------

for key_name in "${SSH_KEYS[@]}"; do
  key_path="$HOME/.ssh/$key_name"
  if [ ! -f "$key_path" ]; then
    log "Generating SSH key: $key_name..."
    ssh-keygen -t ed25519 -C "$key_name" -f "$key_path" -N ""
    ok "SSH key generated: $key_name"
  else
    ok "SSH key already exists: $key_name"
  fi
done

# ---------------------------------
# Add keys to ssh-agent
# ---------------------------------

eval "$(ssh-agent -s)" > /dev/null
for key_name in "${SSH_KEYS[@]}"; do
  ssh-add --apple-use-keychain "$HOME/.ssh/$key_name" 2>/dev/null || true
done

# ---------------------------------
# Configure ~/.ssh/config
# ---------------------------------

if ! grep -q "Host github.com" "$SSH_CONFIG" 2>/dev/null; then
  case "$DOTFILES_PROFILE" in
    personal)
      cat >> "$SSH_CONFIG" <<EOF

# =========================
# PERSONAL
# =========================
Host github.com
  HostName github.com
  User git
  IdentityFile $HOME/.ssh/$PERSONAL_KEY
  AddKeysToAgent yes
  UseKeychain yes
EOF
      ok "Personal SSH config added (Host github.com)."
      ;;
    work)
      cat >> "$SSH_CONFIG" <<EOF

# =========================
# WORK (InTech)
# =========================
Host github.com
  HostName github.com
  User git
  IdentityFile $HOME/.ssh/$WORK_KEY
  AddKeysToAgent yes
  UseKeychain yes
EOF
      ok "Work SSH config added (Host github.com)."
      ;;
    both)
      cat >> "$SSH_CONFIG" <<EOF

# =========================
# WORK (InTech) — default for github.com
# =========================
Host github.com
  HostName github.com
  User git
  IdentityFile $HOME/.ssh/$WORK_KEY
  AddKeysToAgent yes
  UseKeychain yes

Host github-work
  HostName github.com
  User git
  IdentityFile $HOME/.ssh/$WORK_KEY
  AddKeysToAgent yes
  UseKeychain yes

# =========================
# PERSONAL
# =========================
Host github-personal
  HostName github.com
  User git
  IdentityFile $HOME/.ssh/$PERSONAL_KEY
  AddKeysToAgent yes
  UseKeychain yes
EOF
      ok "Both SSH configs added (github.com default=work, github-work, github-personal)."
      ;;
  esac
else
  ok "SSH config for github.com already present."
fi

chmod 600 "$SSH_CONFIG"

# ---------------------------------
# Show public keys for GitHub
# ---------------------------------

echo ""
log "Add the following public keys to GitHub (https://github.com/settings/keys):"
echo ""
for key_name in "${SSH_KEYS[@]}"; do
  warn "── $key_name ──"
  cat "$HOME/.ssh/$key_name.pub"
  echo ""
done
