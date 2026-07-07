# dotfile — Shared Config for Docker/Headless Environments

Minimal dotfile repo. Cloned into a shared folder mounted across Docker containers so all containers share the same Claude Code / Codex sessions, API keys, and runtime state.

## Architecture

```
~/dotfile/          ← this repo (cloned from git)
  ├── .claude/      ← runtime dir (gitignored), symlinked to ~/.claude
  ├── .codex/       ← runtime dir (gitignored), symlinked to ~/.codex
  ├── .agents/      ← runtime dir (gitignored)
  ├── zsh/          ← modules sourced into generated ~/.zshrc
  ├── tmux/         ← symlinked to ~/.tmux.conf
  ├── git/          ← symlinked to ~/.gitconfig
  ├── nvim/         ← symlinked to ~/.config/nvim
  ├── yazi/         ← symlinked to ~/.config/yazi
  └── init.sh       ← idempotent bootstrap script
```

Key design:
- `~/.claude` → `~/dotfile/.claude` (symlink). All runtime state (sessions, settings.json, API keys) lives in the shared folder and is gitignored.
- `~/.codex` → `~/dotfile/.codex` (symlink). Same pattern.
- Rules, skills, agents, hooks are NOT tracked in this repo — this repo only provides the symlink + shared runtime storage.

## Provisioning a new machine

```bash
git clone <url> ~/dotfile
cd ~/dotfile
./init.sh
```

After `init.sh`, create secret files manually:
- `~/.claude/settings.json` — API tokens, env vars
- `~/.claude/config.json` — internal config
- `~/.codex/auth.json` / `~/.codex/config.toml` — Codex CLI credentials

These are gitignored. On a shared-folder setup, create them once and all containers see them.

## Shared folder / Docker setup

Mount the shared folder at `~/dotfile/` in each container, then run `./init.sh` to create symlinks. All containers share:
- Claude Code sessions, history, and API keys
- Codex CLI sessions and credentials

Nothing sensitive is ever tracked in git.
