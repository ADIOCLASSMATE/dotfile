# dotfile

Minimal dotfile repo for shell, editor, and AI coding agent config. Designed for shared-folder setups across Docker containers.

## Quick start

```bash
git clone <repo-url> ~/dotfile
cd ~/dotfile
./init.sh
```

`init.sh` installs packages, creates symlinks, and generates `~/.zshrc`. Idempotent — safe to rerun.

## What gets configured

| Component | Source | Target |
|-----------|--------|--------|
| Shell (zsh) | `zsh/zshrc.d/*.zsh` | `~/.zshrc` (generated) |
| tmux | `tmux/.tmux.conf` | `~/.tmux.conf` (symlink) |
| Git | `git/.gitconfig` | `~/.gitconfig` (symlink) |
| Neovim | `nvim/` | `~/.config/nvim` (symlink) |
| Yazi | `yazi/` | `~/.config/yazi` (symlink) |
| Claude Code | `.claude/` (runtime, gitignored) | `~/.claude` (symlink) |
| Codex CLI | `.codex/` (runtime, gitignored) | `~/.codex` (symlink) |

## Secrets

Create these manually (gitignored):
- `~/.claude/settings.json` — Claude Code API keys and hooks
- `~/.claude/config.json` — Claude Code internal config
- `~/.codex/auth.json` / `~/.codex/config.toml` — Codex CLI credentials

## Docker / shared folder

Mount this repo at `~/dotfile/` in each container, run `./init.sh` once. All containers share sessions, API keys, and runtime state via the symlinked `.claude/` and `.codex/` directories.
