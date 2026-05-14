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

## Prerequisites

Before provisioning, verify these tools are available. If any are missing, ask the user to install them or install via the OS package manager:

- `git` — required to clone this repo
- `node` — required for Claude Code hooks (`gateguard-fact-force.js`, `on-plan-accepted.js`, etc.)
- `jq` — required for `statusline.sh` and `setup-hooks.sh`

## Provisioning a new machine

### Step 1: Clone and bootstrap

```bash
# Ask the user for the repo URL, then:
git clone <url> ~/dotfile
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

After `init.sh` completes, it prints a summary. Check the **Warnings** section — any tool listed there needs attention before continuing. If init.sh succeeded without warnings, proceed to Step 2.

### Step 2: Verify symlinks

```bash
ls -la ~/.claude ~/.codex ~/.tmux.conf ~/.gitconfig ~/.config/nvim ~/.config/yazi
```

All should point into `~/dotfile/`. If any is missing or broken, re-run `./init.sh`.

### Step 3: Create secret files (manual, not in git)

These files are gitignored and must be created on each machine. Ask the user for secret values (tokens, API endpoints, model IDs), then create each file with the template below.

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
    "PostToolUse": [
      {
        "matcher": "ExitPlanMode",
        "hooks": [{ "type": "command", "command": "node ~/dotfile/.claude/scripts/hooks/on-plan-accepted.js", "timeout": 10 }]
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

> The template above includes all hooks. `setup-hooks.sh` is only needed when adding new hooks to an existing `settings.json` on an already-provisioned machine.

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

Edit `~/.zshrc` and modify only the block between:
```
# >>> dotfile local block >>>
# <<< dotfile local block <<<
```

Put machine-only exports here (private paths, cluster URLs, etc.). This block survives `init.sh` reruns.

### Step 5: Install Neovim plugins

```bash
nvim --headless "+Lazy! sync" +qa  # installs LazyVim plugins non-interactively
```

Requires internet access.

### Step 6: Verify tooling

```bash
# Check core tools are on PATH
which zsh tmux git curl rg fzf nvim yazi

# Check Claude Code reads its config
ls -la ~/.claude/settings.json ~/.claude/config.json

# Check statusline works
~/.claude/statusline.sh < /dev/null 2>&1 || echo "statusline needs jq"
```

## Linux / Docker / Headless specifics

In minimal or headless environments, some tools may be missing:

1. **No sudo / no apt**: `init.sh` still creates symlinks and generates `~/.zshrc`. Install packages manually or as root before running.
2. **Headless environment**: `desktop-notify.js` silently skips on Linux without WSL/PowerShell. No action needed.

## What lives where

### .claude/ (Claude Code)

| Path | What | Tracked |
|------|------|---------|
| `agents/*.md` | Subagent definitions (25 agents) | Yes |
| `skills/*/SKILL.md` | Skill definitions (40 skills) | Yes |
| `rules/` | Layered rules (common + language-specific) | Yes |
| `scripts/hooks/*.js` | PreToolUse / PostToolUse / PostCompact / Stop hooks | Yes |
| `scripts/setup-hooks.sh` | One-shot hook config installer for settings.json | Yes |
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
| Hook config (new/changed) | Run `bash ~/dotfile/.claude/scripts/setup-hooks.sh` |

## Troubleshooting

- **Symlink broken**: `ls -la ~/.claude` should show `-> ~/dotfile/.claude`. If not, `./init.sh` will fix it.
- **Hooks not firing**: Check `~/.claude/settings.json` exists and hook paths use `~/dotfile/.claude/scripts/hooks/` (resolves via symlink).
- **Statusline empty**: Ensure `jq` and `zsh` are installed. `statusline.sh` sources `~/.claude/pet/utils.sh`.
- **Neovim plugins missing**: First launch needs internet. If LazyVim errors, check `nvim --version` is >= 0.8.0.
- **Claude Code can't find rules**: `~/.claude` must be a symlink, not a directory. If someone created a real `~/.claude/` dir, back it up and re-run `./init.sh`.
