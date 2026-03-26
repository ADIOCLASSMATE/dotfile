typeset -U path PATH

[[ -d "$HOME/.local/bin" ]] && path=("$HOME/.local/bin" $path)

if [[ "$(uname -s)" == "Darwin" ]]; then
  [[ -d "/opt/homebrew/bin" ]] && path=("/opt/homebrew/bin" $path)
  [[ -d "/Library/TeX/texbin" ]] && path=("/Library/TeX/texbin" $path)
fi
