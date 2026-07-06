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

### Profile differences

| Feature | `personal` | `work` | `both` |
|---------|-----------|--------|--------|
| Brewfile | `Brewfile.personal` | `Brewfile.work` | `Brewfile.both` |
| Dock script | `dock-personal.sh` | `dock-work.sh` | `dock-both.sh` |
| Photos.app in Dock | ✓ | — | ✓ |
| Microsoft Outlook/Teams | — | ✓ | ✓ |
| Linear in Dock | — | ✓ | ✓ |
| Spotify/VLC in Dock | ✓ | — | ✓ |

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

## New Tools

| Tool | Type | Description |
|------|------|-------------|
| `raycast` | cask | Launcher, clipboard history, snippets — replaces Spotlight |
| `obsidian` | cask | Markdown note-taking with local-first storage |
| `imageoptim` | cask | Lossless image compression |
| `bruno` | cask | Open-source REST/GraphQL client |
| `git-delta` | brew | Improved `git diff` with syntax highlighting |
| `tldr` | brew | Simplified man pages with practical examples |
| `httpie` | brew | User-friendly HTTP client for APIs |
| `lazygit` | brew | Terminal UI for git |
| `nvm` | brew | Node.js version manager |

## Aliases

### GitHub CLI shortcuts

| Alias | Command | Description |
|-------|---------|-------------|
| `ghopen` | `gh repo view --web` | Open current repo in GitHub |
| `ghpr` | `gh pr list` | List open PRs for current repo |
| `ghprc` | `gh pr create --web` | Create a PR in the browser |
| `gclean` | `git branch --merged \| ...` | Delete local branches already merged (excludes main/master/develop) |

## macOS Defaults

The following defaults are applied automatically by `macos/macos.sh`:

| Setting | Value | Key |
|---------|-------|-----|
| Screenshots folder | `~/Desktop/Screenshots` | `com.apple.screencapture location` |
| Screenshot shadow | Disabled | `com.apple.screencapture disable-shadow` |
| Mission Control animation | 0.1s | `com.apple.dock expose-animation-duration` |
| Battery percentage | Shown | `com.apple.menuextra.battery ShowPercent` |
| Auto-correction | Disabled | `NSAutomaticSpellingCorrectionEnabled` |
| Wallpaper | `macos/Wallpaper.png` | osascript System Events |

To change the wallpaper, replace `macos/Wallpaper.png` with a new image and commit. The new image will be applied on the next bootstrap run.

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

## System Snapshot & Restore

The snapshot system lets you capture the current state of a Mac and restore it on a new machine after running bootstrap.

### What `dotsnapshot` captures

- **Overrides** — `defaults` keys that differ from what `macos/macos.sh` sets (only what you changed manually after bootstrap)
- **Everything without a bootstrap baseline** — installed apps (Brewfile dump), VS Code extensions, Dock layout, Login Items, Launch Agents, display resolution, trackpad/mouse/keyboard settings, sound, accessibility, WiFi network names, energy settings, language/region, git config, NVM versions

Run it on the source machine before wiping or replacing it:

```bash
dotsnapshot
# or
bash ~/dotfiles/scripts/snapshot.sh
```

Each machine gets its own snapshot directory named by model and chip — e.g. `snapshots/MacBook-Air-M4/`. Running `dotsnapshot` again on the same machine overwrites its snapshot (current state, not history). Multiple machines each keep their own snapshot in the repo. Commit after snapshotting so it's available when you clone on the new machine:

```bash
cd ~/dotfiles
git add snapshots/
git commit -m "chore: update system snapshot"
git push origin main
```

### What `dotrestore` does

Run it on the new machine **after** the normal `bootstrap.sh`:

```bash
dotrestore
# or
bash ~/dotfiles/scripts/restore.sh
```

It lists all available machine snapshots and prompts you to choose one — useful when migrating from a specific old machine or when you have multiple machines in the repo. It then applies everything it can automatically and prints a three-section report:

| Section | Meaning |
|---------|---------|
| ✓ Fully restored | Applied programmatically — no action needed |
| ⚠ Partially restored | Reference file saved; manual step required |
| ✗ Could not restore | Missing data or unrecoverable |

### What can never be restored automatically

| Item | Why | What to do |
|------|-----|------------|
| Keychain (passwords, tokens, certs) | macOS security restriction | Re-authenticate in each app |
| Paid app licenses (non-Surfshark) | No export API | Re-enter license keys from email |
| WiFi passwords | Not exportable from Keychain | Re-enter when connecting |
| Login Items | macOS 13+ blocks programmatic addition | Add via System Settings > General > Login Items |
| iCloud / Apple ID session | Account-bound | Sign in again |

Surfshark config can be backed up separately with `dotlicenses`.

### Recommended workflow when replacing a Mac

1. On old Mac: `dotsnapshot` → commit → push
2. On new Mac: run install script → `bootstrap.sh` → `dotrestore`
3. Follow the ⚠ items in the restore report

## How Stow Works

Each top-level folder (except `macos`, `lib`, `profiles`, `docs`) is a Stow package.
Files inside are symlinked relative to `$HOME`.

Example:
```
zsh/.zshrc  →  ~/.zshrc
git/.gitconfig  →  ~/.gitconfig
fastfetch/.config/fastfetch/config.jsonc  →  ~/.config/fastfetch/config.jsonc
```
