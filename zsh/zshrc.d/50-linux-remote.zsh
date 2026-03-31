if [[ "$(uname -s)" == "Linux" ]]; then
  if [[ -f "$HOME/.local/bin/env" ]]; then
    source "$HOME/.local/bin/env"
  fi

  export HF_ENDPOINT="https://hf-mirror.com"
  export UV_PYTHON="3.12"
fi
