# dotfile

This repository turns the current working shell, tmux, Neovim, Yazi, and baseline Git configuration into a git-managed dotfiles setup that can be replayed on macOS and remote Linux hosts. The local files under `/Users/wjx` were treated as the only source of truth, and secrets or machine-only values were moved out of tracked config.

## Managed files

- `zsh/.zshrc` plus modular `zsh/zshrc.d/*.zsh`
- `tmux/.tmux.conf`
- `git/.gitconfig`
- `nvim/` copied from the active LazyVim config
- `yazi/yazi.toml`
- `install.sh` for bootstrap, package installation, backups, and symlink management

## Layout

```text
dotfile/
├── README.md
├── install.sh
├── .gitignore
├── zsh/
│   ├── .zshrc
│   └── zshrc.d/
│       ├── 00-paths.zsh
│       ├── 10-oh-my-zsh.zsh
│       ├── 20-aliases.zsh
│       ├── 30-completions.zsh
│       ├── 40-tools.zsh
│       ├── 50-linux-remote.zsh
│       ├── 90-private.example.zsh
│       └── 99-private.local.zsh
├── tmux/
│   └── .tmux.conf
├── git/
│   └── .gitconfig
├── nvim/
│   ├── init.lua
│   ├── lazy-lock.json
│   ├── lazyvim.json
│   └── lua/
│       ├── config/
│       │   ├── autocmds.lua
│       │   ├── keymaps.lua
│       │   ├── lazy.lua
│       │   └── options.lua
│       └── plugins/
│           └── python-shell.lua
└── yazi/
    └── yazi.toml
```

`99-private.local.zsh` is generated locally by `./install.sh` from `90-private.example.zsh` if it does not already exist. It is ignored by git.

## Bootstrap

```bash
git clone <your-repo-url> ~/dotfile
cd ~/dotfile
./install.sh
```

The installer detects `uname`, creates backups under `~/.dotfile-backups/<timestamp>/`, manages symlinks without GNU Stow, installs tools on a best-effort basis, installs Oh My Zsh if missing, installs Neovim and Yazi when possible, adds common Yazi runtime helpers when package management is available, creates `99-private.local.zsh` from the template when needed, and prints a final summary of completed, skipped, and warning items.

The script uses the repository location it is executed from, so it works both for `/Users/wjx/dotfile` on macOS and for any cloned path on Linux.
Run the script as your normal user. It will use `sudo` internally for `apt` when needed; if you start it with `sudo`, it will re-exec itself as the original user before managing dotfiles.

## Secrets and private values

Tracked files do not contain plaintext credentials, passwords, tokens, server-only directories, or machine-only paths. Put those values in `zsh/zshrc.d/99-private.local.zsh`.

Workflow:

1. Run `./install.sh` once to generate `zsh/zshrc.d/99-private.local.zsh` from the example.
2. Edit `zsh/zshrc.d/99-private.local.zsh` and uncomment or add only the values you need locally.
3. Keep any custom paths such as private tool directories or cluster-only cache locations in that local file.

## Fresh Linux server

On a new Linux host:

```bash
git clone <your-repo-url> ~/dotfile
cd ~/dotfile
./install.sh
```

Linux behavior:

- If `apt-get` and `sudo` are available, the installer tries to install `zsh tmux git curl ripgrep fzf neovim` plus common Yazi support packages such as `file`, `jq`, `ffmpeg`, `p7zip`, `poppler`, and `imagemagick`.
- If the host is already root, it uses `apt-get` directly.
- If `sudo` is unavailable, it skips system packages and still tries user-level Rust and Cargo-based Yazi installation.
- If Cargo is available, Yazi is installed with `cargo install --force yazi-build`, which is the current upstream-supported path for crates.io.
- On Linux, if the distro `neovim` package is missing or older than `0.8.0`, the installer falls back to the official Neovim tarball under `~/.local/opt` and links `~/.local/bin/nvim`.
- After installation, the script warns if `nvim`, `yazi`, or key Yazi helper commands are still missing.
- `50-linux-remote.zsh` only loads Linux-only logic behind guards, including optional `nvm`, optional `$HOME/.local/bin/env`, a minimal welcome banner, and safe Linux tool exports.

## Re-running safely

`./install.sh` is intended to be safe to rerun.

- Existing correct symlinks are skipped.
- Existing non-matching files or links are moved to `~/.dotfile-backups/<timestamp>/` before new links are created.
- No target is overwritten silently.
- Missing optional installers produce warnings instead of aborting the whole run.

## After editing the repo

For shell changes:

```bash
source ~/.zshrc
```

For tmux changes, reload with:

```bash
tmux source-file ~/.tmux.conf
```

For Neovim and Yazi, restart the application. On first Neovim startup, LazyVim may need network access to fetch plugins pinned in `lazy-lock.json`.

## FAQ

### Default shell did not change

If `chsh` failed or requires privileges, run:

```bash
chsh -s "$(command -v zsh)"
```

Then log out and back in. Some remote environments also require the target shell to be listed in `/etc/shells`.

### Remote host does not have zsh

Re-run `./install.sh`. If package installation still fails, install `zsh` with the system package manager manually, then run the script again.

### Linux host has no sudo

The installer will still set up symlinks, try to install Rust with `rustup`, and install Yazi with Cargo if possible. For `zsh`, `tmux`, `git`, `curl`, `ripgrep`, `fzf`, and `neovim`, install them manually or ask an administrator to do so.

### Neovim fails on first launch

The bundled config uses LazyVim and `lazy.nvim`. First launch may need internet access to clone plugin sources before the lockfile can be applied locally.
On older Linux distros, the system `neovim` package may be too old for LazyVim. `./install.sh` now falls back to an official Neovim build if it detects a version older than `0.8.0`.

### Yazi cannot open files in Neovim

This repo uses `nvim %s` as the editor opener so the same config works on macOS and Linux. If `nvim` is not on `PATH`, install Neovim or add the correct path in your private local zsh file.
