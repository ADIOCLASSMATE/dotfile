typeset -g DOTFILES_ZSH_DIR="${${(%):-%N}:A:h}"

for zsh_file in "$DOTFILES_ZSH_DIR"/zshrc.d/*.zsh(N); do
  source "$zsh_file"
done

unset zsh_file
