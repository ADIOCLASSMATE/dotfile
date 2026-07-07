# Load clashctl when it is installed in the current container's home.
_clashctl_script="${CLASHCTL_HOME:-}/scripts/cmd/clashctl.sh"
_clashctl_env="${CLASHCTL_HOME:-}/.env"

if [[ (! -f "$_clashctl_script" || ! -f "$_clashctl_env") && -f "$HOME/clashctl/scripts/cmd/clashctl.sh" && -f "$HOME/clashctl/.env" ]]; then
  export CLASHCTL_HOME="$HOME/clashctl"
  _clashctl_script="$CLASHCTL_HOME/scripts/cmd/clashctl.sh"
  _clashctl_env="$CLASHCTL_HOME/.env"
fi

if [[ -f "$_clashctl_script" && -f "$_clashctl_env" ]]; then
  source "$_clashctl_script"
fi

unset _clashctl_script _clashctl_env
