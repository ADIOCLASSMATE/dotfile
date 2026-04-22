# dotfile — Machine Provisioning Guide

This repo contains all config needed to reproduce a development environment on macOS or Linux. When you (the agent) are given a new machine, follow the instructions below.

## Architecture

```
~/dotfile/          ← this repo (cloned from git)
  ├── .claude/      ← symlinked to ~/.claude
  ├── .codex/       ← symlinked to ~/.codex
  ├── zsh/          ← modules sourced into generated ~/.zshrc
  ├── tmux/         ← symlinked to ~/.tmux.conf
  ├── git/          ← symlinked to ~/.gitconfig
  ├── nvim/         ← symlinked to ~/.config/nvim
  ├── yazi/         ← symlinked to ~/.config/yazi
  └── init.sh       ← idempotent bootstrap script
```

Key design: `~/.claude` and `~/.codex` are **symlinks into this repo**, not copies. All agents, skills, rules, hooks, and statusline config are version-controlled here. Runtime state (sessions, transcripts, plans) lives inside the same directory tree and is gitignored.

## Provisioning a new machine

### Step 1: Clone and bootstrap

```bash
git clone <repo-url> ~/dotfile
cd ~/dotfile
./init.sh
```

`init.sh` is idempotent — safe to rerun. It:
- Detects OS (macOS → Homebrew, Linux → apt-get)
- Installs: zsh, tmux, git, curl, ripgrep, fzf, neovim, Yazi support tools
- Installs Oh My Zsh + plugins (autosuggestions, syntax-highlighting)
- Installs Rust + Yazi via rustup/cargo
- Falls back to official Neovim tarball on Linux if system nvim < 0.8.0
- Backs up conflicts to `~/.dotfile-backups/<timestamp>/`
- Creates symlinks: `~/.tmux.conf`, `~/.gitconfig`, `~/.config/nvim`, `~/.config/yazi`, `~/.claude`, `~/.codex`
- Generates `~/.zshrc` from tracked zsh modules
- Switches default shell to zsh

### Step 2: Verify symlinks

```bash
ls -la ~/.claude ~/.codex ~/.tmux.conf ~/.gitconfig ~/.config/nvim ~/.config/yazi
```

All should point into `~/dotfile/`. If any is missing or broken, re-run `./init.sh`.

### Step 3: Create secret files (manual, not in git)

These files are gitignored and must be created on each machine:

**`~/.claude/settings.json`** — Claude Code configuration:
```json
{
  "env": {
    "ANTHROPIC_AUTH_TOKEN": "<your-token>",
    "ANTHROPIC_BASE_URL": "<your-api-endpoint>",
    "ANTHROPIC_DEFAULT_OPUS_MODEL": "<model-id>",
    "ANTHROPIC_DEFAULT_SONNET_MODEL": "<model-id>",
    "ANTHROPIC_DEFAULT_HAIKU_MODEL": "<model-id>",
    "CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC": "1"
  },
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Edit|Write|MultiEdit",
        "hooks": [{ "type": "command", "command": "node ~/dotfile/.claude/scripts/hooks/gateguard-fact-force.js", "timeout": 5 }]
      },
      {
        "matcher": "Bash",
        "hooks": [
          { "type": "command", "command": "node ~/dotfile/.claude/scripts/hooks/gateguard-fact-force.js", "timeout": 5 },
          { "type": "command", "command": "node ~/dotfile/.claude/scripts/hooks/pre-bash-commit-quality.js" }
        ]
      }
    ],
    "Stop": [
      {
        "matcher": "",
        "hooks": [{ "type": "command", "command": "node ~/dotfile/.claude/scripts/hooks/desktop-notify.js", "timeout": 10, "async": true }]
      }
    ],
    "PostCompact": [
      {
        "matcher": "",
        "hooks": [{ "type": "command", "command": "node ~/dotfile/.claude/scripts/hooks/post-compact-context-restore.js", "timeout": 15 }]
      }
    ]
  },
  "statusLine": {
    "type": "command",
    "command": "~/.claude/statusline.sh",
    "padding": 2,
    "refreshInterval": 3
  }
}
```

**`~/.claude/config.json`** — Internal config:
```json
{
  "customApiKeyResponses": {
    "approved": []
  }
}
```

**`~/.codex/auth.json`** and **`~/.codex/config.toml`** — if using Codex CLI.

### Step 4: Configure machine-specific shell values

Open `~/.zshrc` and edit only the block between:
```
# >>> dotfile local block >>>
# <<< dotfile local block <<<
```

Put machine-only exports here (private paths, cluster URLs, etc.). This block survives `init.sh` reruns.

### Step 5: Install Neovim plugins

```bash
nvim  # first launch — LazyVim installs plugins from lazy-lock.json
```

Requires internet access. Wait for plugin installation to complete.

### Step 6: Verify tooling

```bash
# Check core tools are on PATH
which zsh tmux git curl rg fzf nvim yazi

# Check Claude Code reads its config
ls -la ~/.claude/settings.json ~/.claude/config.json

# Check statusline works
~/.claude/statusline.sh < /dev/null 2>&1 || echo "statusline needs jq"
```

## Linux Docker specifics

In a minimal Docker container, some tools may be missing:

1. **No sudo / no apt**: `init.sh` still creates symlinks and generates `~/.zshrc`. Install packages manually or as root before running.
2. **Node.js**: Required for Claude Code hooks. Install via `apt install nodejs` or via nvm (see `zsh/zshrc.d/60-nvm.zsh`).
3. **jq**: Required by `statusline.sh`. `apt install jq` or `brew install jq`.
4. **Headless environment**: `desktop-notify.js` silently skips on Linux without WSL/PowerShell. No action needed.

## What lives where

### .claude/ (Claude Code)

| Path | What | Tracked |
|------|------|---------|
| `agents/*.md` | Subagent definitions (44 agents) | Yes |
| `skills/*/SKILL.md` | Skill definitions (38 skills) | Yes |
| `rules/` | Layered rules (common + language-specific) | Yes |
| `scripts/hooks/*.js` | PreToolUse / PostCompact / Stop hooks | Yes |
| `pet/` | Statusline cat animation data | Yes |
| `statusline.sh` | Status bar renderer | Yes |
| `mcp-configs/mcp-servers.json` | MCP template catalog (no live creds) | Yes |
| `settings.json` | API tokens, env vars, hook config | **No** — gitignored |
| `config.json` | Internal Claude Code config | **No** — gitignored |
| `sessions/`, `transcripts/`, `plans/`, etc. | Runtime state | **No** — gitignored |

### .codex/ (OpenAI Codex CLI)

| Path | What | Tracked |
|------|------|---------|
| `rules/default.rules` | Codex allow-list rules | Yes |
| `skills/feynman/` | Research skills | Yes |
| `skills/.system/` | System skills | Yes |
| `vendor_imports/skills/` | Upstream skill sync (submodule) | Yes |
| `auth.json` | Credentials | **No** — gitignored |
| `config.toml` | Config | **No** — gitignored |
| `sessions/`, `log/`, `*.sqlite` | Runtime state | **No** — gitignored |

## Updating after repo changes

| Change type | Apply with |
|-------------|-----------|
| Shell modules | `./init.sh && source ~/.zshrc` |
| tmux | `tmux source-file ~/.tmux.conf` |
| Neovim / Yazi | Restart application |
| Claude Code rules, skills, agents, hooks | Immediate — `~/.claude` is a live symlink |
| Claude Code settings (hooks, env) | Edit `~/.claude/settings.json` manually — not in repo |

## Troubleshooting

- **Symlink broken**: `ls -la ~/.claude` should show `-> ~/dotfile/.claude`. If not, `./init.sh` will fix it.
- **Hooks not firing**: Check `~/.claude/settings.json` exists and hook paths use `~/dotfile/.claude/scripts/hooks/` (resolves via symlink).
- **Statusline empty**: Ensure `jq` and `zsh` are installed. `statusline.sh` sources `~/.claude/pet/utils.sh`.
- **Neovim plugins missing**: First launch needs internet. If LazyVim errors, check `nvim --version` is >= 0.8.0.
- **Claude Code can't find rules**: `~/.claude` must be a symlink, not a directory. If someone created a real `~/.claude/` dir, back it up and re-run `./init.sh`.
