export CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC=1

export BUN_INSTALL="$HOME/.bun"
if [[ -d "$BUN_INSTALL/bin" ]]; then
  typeset -U path PATH
  path=("$BUN_INSTALL/bin" $path)
fi
