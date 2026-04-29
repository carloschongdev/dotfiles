#!/usr/bin/env bash
set -euo pipefail

DOTFILES_DIR="${DOTFILES_DIR:-$HOME/dotfiles}"
source "$DOTFILES_DIR/lib/logging.sh"

# PROFILE_NAME and PROFILE_SSH_KEYS must be set (sourced from profile file)
: "${PROFILE_NAME:?PROFILE_NAME not set — source a profile before running this script}"
: "${PROFILE_SSH_KEYS:?PROFILE_SSH_KEYS not set — source a profile before running this script}"

log "Configuring SSH for profile: $PROFILE_NAME..."

SSH_CONFIG="$HOME/.ssh/config"

# ---------------------------------
# Create ~/.ssh dir
# ---------------------------------

mkdir -p "$HOME/.ssh"
chmod 700 "$HOME/.ssh"

# ---------------------------------
# Generate keys defined in PROFILE_SSH_KEYS
# ---------------------------------

for key_name in "${PROFILE_SSH_KEYS[@]}"; do
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
for key_name in "${PROFILE_SSH_KEYS[@]}"; do
  ssh-add "$HOME/.ssh/$key_name" 2>/dev/null || true
done

# ---------------------------------
# Configure ~/.ssh/config
# ---------------------------------

case "$PROFILE_NAME" in
  personal)
    if ! grep -q "Host github.com" "$SSH_CONFIG" 2>/dev/null; then
      cat >> "$SSH_CONFIG" <<EOF

# =========================
# PERSONAL
# =========================
Host github.com
  HostName github.com
  User git
  IdentityFile $HOME/.ssh/id_carloschongdev_personal
  AddKeysToAgent yes
  UseKeychain yes
EOF
      ok "Personal SSH config added (Host github.com)."
    else
      ok "SSH config for github.com already present."
    fi
    ;;

  work)
    if ! grep -q "Host github.com" "$SSH_CONFIG" 2>/dev/null; then
      cat >> "$SSH_CONFIG" <<EOF

# =========================
# WORK (InTech)
# =========================
Host github.com
  HostName github.com
  User git
  IdentityFile $HOME/.ssh/id_CarlosChong28_work
  AddKeysToAgent yes
  UseKeychain yes
EOF
      ok "Work SSH config added (Host github.com)."
    else
      ok "SSH config for github.com already present."
    fi
    ;;

  both)
    if ! grep -q "Host github-work" "$SSH_CONFIG" 2>/dev/null; then
      cat >> "$SSH_CONFIG" <<EOF

# =========================
# WORK (InTech)
# =========================
Host github-work
  HostName github.com
  User git
  IdentityFile $HOME/.ssh/id_CarlosChong28_work
  AddKeysToAgent yes
  UseKeychain yes
EOF
      ok "Work SSH config added (Host github-work)."
    else
      ok "Work SSH config already present."
    fi

    if ! grep -q "Host github-personal" "$SSH_CONFIG" 2>/dev/null; then
      cat >> "$SSH_CONFIG" <<EOF

# =========================
# PERSONAL
# =========================
Host github-personal
  HostName github.com
  User git
  IdentityFile $HOME/.ssh/id_carloschongdev_personal
  AddKeysToAgent yes
  UseKeychain yes
EOF
      ok "Personal SSH config added (Host github-personal)."
    else
      ok "Personal SSH config already present."
    fi
    ;;
esac

chmod 600 "$SSH_CONFIG"

# ---------------------------------
# Show public keys for GitHub
# ---------------------------------

echo ""
log "Add the following public keys to GitHub (https://github.com/settings/keys):"
echo ""
for key_name in "${PROFILE_SSH_KEYS[@]}"; do
  warn "── $key_name ──"
  cat "$HOME/.ssh/$key_name.pub"
  echo ""
done
