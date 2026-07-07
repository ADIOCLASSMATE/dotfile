# dotfile

Minimal dotfile repo for shell, editor, and AI coding agent runtime setup. Designed for shared-folder Docker/headless setups where each container may have a different `$HOME`.

## Quick start

```bash
git clone <repo-url> ~/dotfile
cd ~/dotfile
./init.sh
```

`init.sh` installs packages and user-local tools, creates symlinks, and generates `~/.zshrc`. Idempotent — safe to rerun.

JavaScript tooling is intentionally Bun-first. `init.sh` installs Bun and creates compatibility shims in `~/.bun/bin` for `node`, `npm`, `npx`, `yarn`, `pnpm`, and `corepack`, so tools that probe Node/npm silently run through Bun instead of requiring a separate Node.js/npm install.

Useful modes:

```bash
./init.sh --link-only      # only generate dotfiles/symlinks; no installs or chsh
./init.sh --no-packages    # skip apt/Homebrew installs
./init.sh --no-user-tools  # skip Rust/Bun/Yazi/Oh My Zsh installs
./init.sh --upgrade-neovim # install the latest official Neovim release
./init.sh --no-chsh        # do not change login shell
```

## What gets configured

| Component | Source | Target |
|-----------|--------|--------|
| Shell (zsh) | `zsh/zshrc.d/*.zsh` | `~/.zshrc` (generated) |
| tmux | `tmux/.tmux.conf` | `~/.tmux.conf` (symlink) |
| Git | `git/.gitconfig` | `~/.gitconfig` (symlink) |
| Neovim | `nvim/` | `~/.config/nvim` (symlink) |
| Yazi | `yazi/` | `~/.config/yazi` (symlink) |
| Claude Code | `.claude/` (shared runtime, gitignored) | `~/.claude` (symlink) |
| Codex CLI | `.codex/` (shared runtime, gitignored) | `~/.codex` (symlink) |

## Secrets

Create these manually (gitignored):
- `~/.claude/settings.json` — Claude Code API keys and hooks
- `~/.claude/config.json` — Claude Code internal config
- `~/.codex/auth.json` / `~/.codex/config.toml` — Codex CLI credentials

## Docker / shared folder

Mount this repo at `~/dotfile/` in each container, run `./init.sh` once. All containers share sessions, API keys, hook assets, and runtime state via the symlinked `.claude/` and `.codex/` directories. These runtime directories are intentionally gitignored.
