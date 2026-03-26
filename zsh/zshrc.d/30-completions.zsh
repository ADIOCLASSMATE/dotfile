if command -v openclaw >/dev/null 2>&1; then
  source <(openclaw completion --shell zsh)
fi

if [[ -s "$HOME/.bun/_bun" ]]; then
  source "$HOME/.bun/_bun"
fi
