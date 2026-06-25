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
  test)     SSH_KEYS=() ;;
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
    test)
      echo "(test profile — key name determined interactively)"
      ;;
  esac
  exit 0
fi

log "Configuring SSH for profile: $DOTFILES_PROFILE..."

SSH_CONFIG="$HOME/.ssh/config"

# ---------------------------------
# Test profile — interactive identity setup
# ---------------------------------

if [[ "$DOTFILES_PROFILE" == "test" ]]; then
  echo ""
  echo "  Test profile — custom GitHub identity setup"
  echo ""

  mkdir -p "$HOME/.ssh"
  chmod 700 "$HOME/.ssh"

  # Check existing configuration
  EXISTING_NAME=$(git config --global user.name 2>/dev/null || true)
  EXISTING_EMAIL=$(git config --global user.email 2>/dev/null || true)
  EXISTING_KEYS=$(ls "$HOME/.ssh"/id_* 2>/dev/null | grep -v "\.pub$" || true)

  if [ -n "$EXISTING_NAME" ] || [ -n "$EXISTING_EMAIL" ] || [ -n "$EXISTING_KEYS" ]; then
    echo "  Existing configuration found:"
    echo ""
    [ -n "$EXISTING_NAME" ]  && echo "    Git name  : $EXISTING_NAME"
    [ -n "$EXISTING_EMAIL" ] && echo "    Git email : $EXISTING_EMAIL"
    if [ -n "$EXISTING_KEYS" ]; then
      echo "    SSH keys  :"
      echo "$EXISTING_KEYS" | while read -r key; do
        echo "      - $(basename "$key")"
      done
    fi
    echo ""
    read -rp "  Replace existing configuration? (y/N): " replace_confirm < /dev/tty || true

    if [[ "$replace_confirm" == "y" || "$replace_confirm" == "Y" ]]; then
      git config --global --unset user.name  2>/dev/null || true
      git config --global --unset user.email 2>/dev/null || true
      ok "Git identity cleared."

      if [ -n "$EXISTING_KEYS" ]; then
        echo "$EXISTING_KEYS" | while read -r key; do
          ssh-add -d "$key" 2>/dev/null || true
          rm -f "$key" "${key}.pub"
          ok "Removed key: $(basename "$key")"
        done
      fi

      if [ -f "$SSH_CONFIG" ]; then
        python3 -c "
import re
content = open('$HOME/.ssh/config').read()
cleaned = re.sub(r'\n*#.*\n*Host github\.com\n(?:[ \t]+.*\n)*', '', content)
open('$HOME/.ssh/config', 'w').write(cleaned.strip() + '\n' if cleaned.strip() else '')
" 2>/dev/null || true
        ok "SSH config cleared."
      fi
    else
      ok "Keeping existing configuration."
    fi
  fi

  # Ask for new identity
  echo ""
  read -rp "  GitHub username: " TEST_USERNAME < /dev/tty || true
  TEST_USERNAME=$(echo "$TEST_USERNAME" | tr '[:upper:]' '[:lower:]')
  read -rp "  Git name (full name): " TEST_NAME < /dev/tty || true
  read -rp "  Git email: " TEST_EMAIL < /dev/tty || true

  if [ -z "$TEST_USERNAME" ] || [ -z "$TEST_NAME" ] || [ -z "$TEST_EMAIL" ]; then
    warn "Username, name or email not provided — skipping identity setup."
  else
    git config --global user.name  "$TEST_NAME"
    git config --global user.email "$TEST_EMAIL"
    ok "Git identity set: $TEST_NAME <$TEST_EMAIL>"

    TEST_KEY_NAME="id_${TEST_USERNAME}"

    cat > /tmp/dotfiles_test_identity.tmp <<EOF
PROFILE_GIT_EMAIL="$TEST_EMAIL"
PROFILE_SSH_KEYS=("$TEST_KEY_NAME")
EOF

    key_path="$HOME/.ssh/$TEST_KEY_NAME"
    if [ ! -f "$key_path" ]; then
      log "Generating SSH key: $TEST_KEY_NAME..."
      ssh-keygen -t ed25519 -C "$TEST_EMAIL" -f "$key_path" -N ""
      ok "SSH key generated: $TEST_KEY_NAME"
    else
      ok "SSH key already exists: $TEST_KEY_NAME"
    fi

    eval "$(ssh-agent -s)" > /dev/null
    ssh-add --apple-use-keychain "$key_path" 2>/dev/null || true

    if ! grep -q "Host github.com" "$SSH_CONFIG" 2>/dev/null; then
      cat >> "$SSH_CONFIG" <<EOF

# =========================
# TEST
# =========================
Host github.com
  HostName github.com
  User git
  IdentityFile $HOME/.ssh/$TEST_KEY_NAME
  AddKeysToAgent yes
  UseKeychain yes
EOF
      ok "SSH config added (Host github.com)."
    else
      ok "SSH config already present."
    fi

    chmod 600 "$SSH_CONFIG"

    echo ""
    warn "── $TEST_KEY_NAME ──"
    cat "${key_path}.pub" 2>/dev/null || true
    echo ""
  fi

  exit 0
fi

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
