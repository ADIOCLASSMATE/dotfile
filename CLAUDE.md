# dotfile — Project Context

## Final Goal

Turn the current shell, tmux, Neovim, Yazi, and Git configuration into a git-managed dotfiles setup that can be replayed on macOS and remote Linux hosts. Secrets and machine-only values are excluded from tracked config.

## Implementation Path

1. Track shell modules (`zsh/zshrc.d/*.zsh`), tmux config, git config, Neovim LazyVim config, and Yazi config
2. `init.sh` handles bootstrap: package installation, backup, symlink management, `~/.zshrc` generation
3. Claude Code rules/hooks/plugins are managed under `.claude/`
4. Maintain portability across macOS and Linux

## Known Issues

- (To be updated as issues are discovered)