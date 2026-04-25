# dotfile

Git-managed dotfiles that reproduce a full development environment on macOS and Linux. One clone, one script, and your shell, editor, terminal multiplexer, file manager, and AI coding agents are ready.

## What gets configured

| Component | Source in repo | Target on system |
|-----------|---------------|-----------------|
| Shell (zsh) | `zsh/zshrc.d/*.zsh` | `~/.zshrc` (generated) |
| tmux | `tmux/.tmux.conf` | `~/.tmux.conf` (symlink) |
| Git | `git/.gitconfig` | `~/.gitconfig` (symlink) |
| Neovim (LazyVim) | `nvim/` | `~/.config/nvim` (symlink) |
| Yazi | `yazi/` | `~/.config/yazi` (symlink) |
| Claude Code | `.claude/` | `~/.claude` (symlink) |
| OpenAI Codex | `.codex/` | `~/.codex` (symlink) |

## Quick start

```bash
git clone <repo-url> ~/dotfile
cd ~/dotfile
./init.sh
```

That is it. The installer detects the OS, installs packages, backs up any conflicting files, creates symlinks, generates `~/.zshrc`, and links `~/.claude` and `~/.codex` to this repo.

### After init.sh

1. Source your new shell: `source ~/.zshrc` (or open a new terminal).
2. Fill in machine-specific values in the local block inside `~/.zshrc` (between `# >>> dotfile local block >>>` and `# <<< dotfile local block <<<`).
3. Create `~/.claude/settings.json` and `~/.claude/config.json` with your API credentials (see [Secrets](#secrets-and-private-values) below). These files are gitignored.
4. Create `~/.codex/auth.json` with your Codex credentials if using Codex CLI.
5. Launch `nvim` once to let LazyVim install plugins from `lazy-lock.json`.

## Layout

```text
dotfile/
├── init.sh              # bootstrap script (idempotent, safe to rerun)
├── CLAUDE.md            # instructions for AI agents on how to set up a new machine
├── .gitignore
├── .gitmodules
│
├── zsh/
│   └── zshrc.d/
│       ├── 00-paths.zsh
│       ├── 10-oh-my-zsh.zsh
│       ├── 20-aliases.zsh
│       ├── 30-completions.zsh
│       ├── 40-tools.zsh
│       ├── 50-linux-remote.zsh
│       ├── 60-nvm.zsh
│       ├── 90-private.example.zsh
│       └── 99-private.local.zsh   (gitignored — holds local secrets)
│
├── tmux/
│   └── .tmux.conf
│
├── git/
│   └── .gitconfig
│
├── nvim/
│   ├── init.lua
│   ├── lazy-lock.json
│   ├── lazyvim.json
│   └── lua/
│       ├── config/  (autocmds, keymaps, lazy, options)
│       └── plugins/ (python-shell)
│
├── yazi/
│   └── yazi.toml
│
├── .claude/                     # → symlinked to ~/.claude
│   ├── CLAUDE.md                # global rules (pipeline workflow, coding style)
│   ├── agents/                  # 44 subagent definitions
│   ├── skills/                  # 38 skill definitions
│   ├── rules/                   # layered rules (common, python, rust, swift, ts, web)
│   ├── scripts/hooks/           # PreToolUse / PostCompact / Stop hooks
│   ├── pet/                     # statusline cat animation
│   ├── statusline.sh            # status bar renderer
│   ├── mcp-configs/mcp-servers.json  # MCP template catalog (no live credentials)
│   ├── commands/                # custom slash commands (empty)
│   ├── hooks/                   # hook documentation
│   └── plugins/                 # plugin marketplace (submodule)
│
├── .codex/                      # → symlinked to ~/.codex
│   ├── AGENTS.md
│   ├── rules/default.rules
│   ├── skills/feynman/          # research skills
│   ├── skills/.system/          # system skills (imagegen, openai-docs, etc.)
│   ├── vendor_imports/skills/   # upstream skill sync (submodule)
│   └── version.json
│
└── docs/
    └── CHANGELOG.md
```

## How init.sh works

1. **Detects OS** — macOS uses Homebrew, Linux uses apt-get.
2. **Installs packages** — `zsh tmux git curl ripgrep fzf neovim` plus Yazi support tools.
3. **Installs Oh My Zsh** and plugins (autosuggestions, syntax-highlighting).
4. **Installs Rust + Yazi** via rustup/cargo if not present.
5. **Ensures usable Neovim** — on Linux, falls back to official tarball if system nvim is too old.
6. **Backs up conflicts** — existing files moved to `~/.dotfile-backups/<timestamp>/`.
7. **Creates symlinks** — tmux, git, nvim, yazi, `.claude/`, `.codex/`.
8. **Generates `~/.zshrc`** — from tracked modules, preserving a local block for machine-specific values.
9. **Switches default shell** to zsh if not already.

The script is idempotent — safe to rerun. Existing correct symlinks are skipped, existing files are backed up before replacement, and the local block in `~/.zshrc` is preserved.

## .claude and .codex symlink design

`~/.claude` and `~/.codex` are symlinked to `~/dotfile/.claude` and `~/dotfile/.codex` respectively. This means:

- All agents, skills, rules, hooks, and statusline config live in the git repo and are version-controlled.
- Runtime state (sessions, transcripts, plans, history, etc.) is gitignored and lives inside the same directory tree — the symlink makes it transparent.
- Secret files (`settings.json`, `config.json`, `auth.json`) are gitignored and must be created manually on each machine.

### Files that must be created manually

| File | Purpose | Notes |
|------|---------|-------|
| `~/.claude/settings.json` | Claude Code settings, API keys, hooks | Contains env vars like `ANTHROPIC_AUTH_TOKEN`, `ANTHROPIC_BASE_URL` |
| `~/.claude/config.json` | Claude Code internal config | Contains `customApiKeyResponses` |
| `~/.codex/auth.json` | Codex CLI credentials | Gitignored |
| `~/.codex/config.toml` | Codex CLI config | Gitignored |

On a new machine, copy these from a secure source or create them from scratch.

## Secrets and private values

Tracked files contain no plaintext credentials. Put secrets in:

1. **`~/.zshrc` local block** — for shell-only exports like `JAVA_HOME`, cluster paths.
2. **`~/.claude/settings.json`** — for Claude Code API tokens and base URLs (in the `env` object).
3. **`~/.codex/auth.json`** — for Codex CLI credentials.

The file `zsh/zshrc.d/99-private.local.zsh` is gitignored. If it exists when `init.sh` runs, its contents seed the local block in `~/.zshrc`.

## Fresh Linux server

```bash
git clone <repo-url> ~/dotfile
cd ~/dotfile
./init.sh
```

Linux-specific behavior:

- If `apt-get` and `sudo` are available, installs `zsh tmux git curl ripgrep fzf neovim` plus Yazi support packages.
- If running as root, uses `apt-get` directly.
- If `sudo` is unavailable, skips system packages but still tries Rust/Yazi via cargo.
- Falls back to official Neovim tarball if system nvim < 0.8.0 (required by LazyVim).
- `50-linux-remote.zsh` loads Linux-only logic behind guards.

## Re-running safely

`./init.sh` is idempotent:

- Existing correct symlinks are skipped.
- Conflicting files are backed up, never silently overwritten.
- `~/.zshrc` is regenerated in place, preserving the local block.
- Missing optional tools produce warnings, not errors.

## After editing the repo

| Change | How to apply |
|--------|-------------|
| Shell modules | `./init.sh && source ~/.zshrc` |
| tmux config | `tmux source-file ~/.tmux.conf` |
| Neovim/Yazi | Restart the application |
| Claude Code rules/skills/hooks | Immediate — `~/.claude` is a symlink into the repo |

## Claude Code configuration details

### Agents (44)

Subagent definitions in `.claude/agents/`. Each `.md` file defines a specialized agent (critic, security-reviewer, rust-build-resolver, etc.) that can be spawned via the Agent tool.

### Skills (38)

Skill definitions in `.claude/skills/`. Each has a `SKILL.md` that defines a callable skill (pipeline, tdd-workflow, python-patterns, etc.).

### Rules (layered)

```
.claude/rules/
├── common/      # Language-agnostic (coding style, testing, security, etc.)
├── python/      # Python-specific (environment, type hints, pytest)
├── rust/        # Rust-specific (ownership, cargo)
├── swift/       # Swift-specific (SwiftUI, concurrency)
├── typescript/  # TS/JS-specific (types, async, Zod)
└── web/         # Frontend-specific (CSS, design quality, CWV)
```

Language-specific rules override common rules when they conflict.

### Hooks (4 scripts)

| Hook | Trigger | Purpose |
|------|---------|---------|
| `gateguard-fact-force.js` | PreToolUse (Edit/Write/Bash) | Advisory safety checks for destructive commands, large edits, new files |
| `pre-bash-commit-quality.js` | PreToolUse (Bash) | Commit quality checks (secrets, console.log, conventional format) |
| `desktop-notify.js` | Stop | Native desktop notification when Claude finishes |
| `post-compact-context-restore.js` | PostCompact | Force project state recall and changelog update after context compaction |

### MCP servers

`.claude/mcp-configs/mcp-servers.json` is a **template catalog** — no server is active by default. Copy entries you need to `~/.claude.json` `mcpServers` and fill in credentials.

### Statusline

`.claude/statusline.sh` renders an animated cat in the Claude Code status bar. It reads model name, cost, and context window usage from the status line JSON input. The cat animation data lives in `.claude/pet/`.

## FAQ

### Default shell did not change

```bash
chsh -s "$(command -v zsh)"
```

Log out and back in. Some environments require zsh to be listed in `/etc/shells`.

### Remote host does not have zsh

Re-run `./init.sh`. If package installation still fails, install zsh manually, then run the script again.

### Linux host has no sudo

The installer still sets up symlinks, generates `~/.zshrc`, tries rustup, and installs Yazi with cargo if possible. Install zsh/tmux/git/curl/ripgrep/fzf/neovim manually.

### Neovim fails on first launch

LazyVim needs internet access on first launch to clone plugins. On old Linux distros, `init.sh` installs the official Neovim tarball if system nvim < 0.8.0.

### Yazi cannot open files in Neovim

This config uses `nvim %s` as the editor opener. If `nvim` is not on PATH, add the correct path in the local block inside `~/.zshrc`.

### Claude Code does not pick up rules/skills

Make sure `~/.claude` is a symlink pointing to `~/dotfile/.claude`. Run `ls -la ~/.claude` to verify. If broken, re-run `./init.sh`.

### Claude Code hooks not firing

Hooks are configured in `~/.claude/settings.json` which is gitignored. You must create this file on each new machine. The hook script paths reference `~/dotfile/.claude/scripts/hooks/` — since `~/.claude` is a symlink, the paths resolve correctly.
