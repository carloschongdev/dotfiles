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

Three profiles are supported: **personal**, **work**, and **both**.

Set the profile before running bootstrap:

```bash
DOTFILES_PROFILE=work bash bootstrap.sh
DOTFILES_PROFILE=both bash bootstrap.sh
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

## SSH Keys

Two separate SSH keys are configured, one per GitHub account:

| Key file | GitHub account |
|----------|----------------|
| `~/.ssh/id_carloschongdev_personal` | carloschongdev (personal) |
| `~/.ssh/id_CarlosChong28_work` | CarlosChong28 (work) |

The `ssh/setup_ssh.sh` script generates the keys (if missing) and writes host blocks to `~/.ssh/config` based on the active profile.

### SSH config per profile

| Profile | Host blocks written |
|---------|---------------------|
| `personal` | `github.com` → personal key only |
| `work` | `github.com` → work key only |
| `both` | `github.com` (work, default) + `github-work` + `github-personal` |

In the `both` profile, `github.com` is intentionally mapped to the **work** key because external tools (e.g. Claude Code, IDEs) connect via `git@github.com` and need a deterministic default identity.

### Cloning repos

```bash
# Perfil personal o work — usar siempre:
git clone git@github.com:usuario/REPO.git

# Perfil both — repos de trabajo:
git clone git@github-work:Intechideas-International/REPO.git

# Perfil both — repos personales:
git clone git@github-personal:carloschongdev/REPO.git
```

### Setting the remote for an existing repo

```bash
# Personal repo (perfil both)
git remote set-url origin git@github-personal:carloschongdev/REPO.git

# Work repo (perfil both)
git remote set-url origin git@github-work:Intechideas-International/REPO.git
```

### Testing the connection

```bash
ssh -T git@github.com         # Hi carloschongdev! (personal) · Hi CarlosChong28! (work/both)
ssh -T git@github-personal    # Hi carloschongdev!   (solo perfil both)
ssh -T git@github-work        # Hi CarlosChong28!    (solo perfil both)
```

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
