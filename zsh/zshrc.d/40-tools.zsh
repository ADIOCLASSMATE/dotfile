export CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC=1

# Bun also provides dotfile-managed node/npm/npx compatibility shims here.
export BUN_INSTALL="$HOME/.bun"
if [[ -d "$BUN_INSTALL/bin" ]]; then
  typeset -U path PATH
  path=("$BUN_INSTALL/bin" $path)
fi
