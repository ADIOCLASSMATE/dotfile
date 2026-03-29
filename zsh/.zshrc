typeset -g DOTFILES_ZSH_DIR="${${(%):-%N}:A:h}"

for zsh_file in "$DOTFILES_ZSH_DIR"/zshrc.d/*.zsh(N); do
  source "$zsh_file"
done

unset zsh_file

export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"  # This loads nvm bash_completion
