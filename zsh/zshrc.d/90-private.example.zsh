# ./init.sh copies this template into the local block inside ~/.zshrc
# when no machine-specific config has been created yet.
# Keep secrets, passwords, tokens, machine-specific paths, and server-only
# directories in that local block instead of tracked config.

# Optional custom PATH entries:
# if [[ -d "$HOME/rtunnel" ]]; then
#   typeset -U path PATH
#   path=("$HOME/rtunnel" $path)
# fi

# API endpoints and tokens:
# export ANTHROPIC_BASE_URL="https://example.invalid"
# export ANTHROPIC_AUTH_TOKEN=""
# export WANDB_API_KEY=""
# export OPENAI_API_KEY=""

# Private service credentials:
# export INSPIRE_USERNAME=""
# export INSPIRE_PASSWORD=""

# Machine-specific or cluster-specific directories:
# export INSPIRE_TARGET_DIR="/path/to/private/workdir"
# export HF_HOME="$HOME/.cache/huggingface"
