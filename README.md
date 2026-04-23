# dotfiles

Personal macOS dotfiles for bootstrapping a new MacBook from scratch.
Uses [GNU Stow](https://www.gnu.org/software/stow/) for symlink management and [Homebrew](https://brew.sh) for packages.

## Quick Install

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/carloschongdev/dotfiles/main/install.sh)"
```

This will install Homebrew and Git (if missing), clone this repo to `~/dotfiles`, and run `bootstrap.sh`.

## Prerequisites

- macOS (Apple Silicon recommended)
- Internet connection
- Admin password (for Homebrew and macOS defaults)

All other tools are installed automatically by the bootstrap.

## Folder Structure

| Folder | Description |
|--------|-------------|
| `fastfetch/` | System info display config and custom ASCII logo |
| `ghostty/` | Ghostty terminal emulator theme and settings |
| `git/` | Global git config, aliases, and per-directory identity switching |
| `lib/` | Shared shell utilities sourced by bootstrap scripts |
| `macos/` | macOS system defaults and Dock automation scripts |
| `profiles/` | Bootstrap profiles for work vs personal setup |
| `docs/` | Reference files (not committed — machine-generated) |
| `ssh/` | SSH key generation and GitHub host config script |
| `vscode/` | VS Code editor settings |
| `zsh/` | Zsh config, aliases, and environment exports |

## Profiles

Two profiles are supported: **personal** (default) and **work**.

Set the profile before running bootstrap:

```bash
DOTFILES_PROFILE=work bash bootstrap.sh
```

Or let bootstrap prompt you interactively when no `DOTFILES_PROFILE` env var is set.

### Git identity switching

Git automatically uses the correct identity based on the directory:

| Directory | Identity |
|-----------|----------|
| `~/work/**` | `carlos.chong@intechideas.com` |
| `~/Projects/intechideas/**` | `carlos.chong@intechideas.com` |
| Everywhere else | `carloschong28@hotmail.com` |

No manual switching needed — `git/.gitconfig` uses `includeIf` blocks.

## How to Update Dotfiles

After editing any config file in the repo:

```bash
cd ~/dotfiles
git add -A
git commit -m "update: describe your change"
git push
```

Stow symlinks point directly into the repo, so changes take effect immediately — no re-stowing needed for edits.

To apply new config files (added to the repo):

```bash
cd ~/dotfiles
bash bootstrap.sh
```

## How Stow Works

Each top-level folder (except `macos`, `lib`, `profiles`, `docs`) is a Stow package.
Files inside are symlinked relative to `$HOME`.

Example:
```
zsh/.zshrc  →  ~/.zshrc
git/.gitconfig  →  ~/.gitconfig
fastfetch/.config/fastfetch/config.jsonc  →  ~/.config/fastfetch/config.jsonc
```
