export ZSH="$HOME/.oh-my-zsh"
ZSH_THEME="robbyrussell"

plugins=(git)

for dotfile_omz_plugin in zsh-autosuggestions zsh-syntax-highlighting; do
  if [[ -d "${ZSH_CUSTOM:-$ZSH/custom}/plugins/$dotfile_omz_plugin" || -d "$ZSH/plugins/$dotfile_omz_plugin" ]]; then
    plugins+=("$dotfile_omz_plugin")
  fi
done
unset dotfile_omz_plugin

if [[ -s "$ZSH/oh-my-zsh.sh" ]]; then
  source "$ZSH/oh-my-zsh.sh"
fi
