if [[ "$(uname -s)" != "Linux" ]]; then
  return 0
fi

export NVM_DIR="$HOME/.nvm"
if [[ -s "$NVM_DIR/nvm.sh" ]]; then
  source "$NVM_DIR/nvm.sh"
fi

if [[ -f "$HOME/.local/bin/env" ]]; then
  source "$HOME/.local/bin/env"
fi

if [[ -o interactive && -f "$HOME/.welcome_Inspire" ]]; then
  cat "$HOME/.welcome_Inspire"
  echo
fi

export HF_ENDPOINT="https://hf-mirror.com"
export UV_PYTHON="3.12"
