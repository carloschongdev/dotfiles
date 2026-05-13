#!/usr/bin/env bash
set -euo pipefail

DOTFILES_DIR="${DOTFILES_DIR:-$HOME/dotfiles}"
source "$DOTFILES_DIR/lib/logging.sh"

echo ""
echo "================================================"
echo "  DOTFILES HEALTH CHECK"
echo "================================================"
echo ""

ERRORS=0

# ---------------------------------
# 1. Symlinks
# ---------------------------------

log "Checking symlinks..."

check_symlink() {
  local link="$1"
  if [ -L "$link" ]; then
    local target
    target=$(readlink "$link")
    if echo "$target" | grep -q "dotfiles"; then
      ok "  $link → $target"
    else
      warn "  WRONG TARGET: $link → $target (expected dotfiles path)"
      ERRORS=$((ERRORS + 1))
    fi
  elif [ -f "$link" ] || [ -d "$link" ]; then
    warn "  NOT A SYMLINK: $link (file exists but is not managed by stow)"
    ERRORS=$((ERRORS + 1))
  else
    warn "  MISSING: $link"
    ERRORS=$((ERRORS + 1))
  fi
}

check_symlink "$HOME/.zshrc"
check_symlink "$HOME/.aliases"
check_symlink "$HOME/.exports"
check_symlink "$HOME/.gitconfig"
check_symlink "$HOME/.config/ghostty/config"
check_symlink "$HOME/.config/fastfetch/config.jsonc"

# ---------------------------------
# 2. Git identity
# ---------------------------------

echo ""
log "Checking git identity..."

GIT_EMAIL=$(git config --global user.email 2>/dev/null || echo "not set")
GIT_NAME=$(git config --global user.name 2>/dev/null || echo "not set")
ok "  Global: $GIT_NAME <$GIT_EMAIL>"

if [ -f "$HOME/.gitconfig-work" ]; then
  WORK_EMAIL=$(git config -f "$HOME/.gitconfig-work" user.email 2>/dev/null || echo "not set")
  ok "  Work config: $WORK_EMAIL"
else
  warn "  ~/.gitconfig-work not found"
  ERRORS=$((ERRORS + 1))
fi

# ---------------------------------
# 3. SSH keys
# ---------------------------------

echo ""
log "Checking SSH keys..."

for key in "$HOME/.ssh"/id_*; do
  [ -f "$key" ] || continue
  [[ "$key" == *.pub ]] && continue
  ok "  Found: $(basename "$key")"
done

SSH_TEST=$(ssh -T git@github.com 2>&1 || true)
if echo "$SSH_TEST" | grep -q "successfully authenticated"; then
  ok "  SSH connection: $(echo "$SSH_TEST" | grep -o 'Hi [^!]*')"
else
  warn "  SSH connection failed — run: gh auth login"
  ERRORS=$((ERRORS + 1))
fi

# ---------------------------------
# 4. gh CLI accounts
# ---------------------------------

echo ""
log "Checking gh accounts..."

if command -v gh &> /dev/null; then
  gh auth status 2>/dev/null | grep -E "account|Active" | while read -r line; do
    echo "    $line"
  done
else
  warn "  gh CLI not found"
  ERRORS=$((ERRORS + 1))
fi

# ---------------------------------
# 5. Core tools
# ---------------------------------

echo ""
log "Checking core tools..."

TOOLS=("brew" "git" "stow" "gh" "starship" "fzf" "zoxide" "bat" "eza" "fastfetch")
for tool in "${TOOLS[@]}"; do
  if command -v "$tool" &> /dev/null; then
    ok "  $tool: $(command -v "$tool")"
  else
    warn "  MISSING: $tool"
    ERRORS=$((ERRORS + 1))
  fi
done

# ---------------------------------
# 6. Claude CLI
# ---------------------------------

echo ""
log "Checking Claude CLI..."
if command -v claude &> /dev/null; then
  ok "  claude: $(claude --version 2>/dev/null || echo 'installed')"
else
  warn "  claude not in PATH — check ~/.exports"
  ERRORS=$((ERRORS + 1))
fi

# ---------------------------------
# Summary
# ---------------------------------

echo ""
echo "================================================"
if [ "$ERRORS" -eq 0 ]; then
  ok "All checks passed!"
else
  warn "$ERRORS issue(s) found — review warnings above"
fi
echo "================================================"
echo ""
