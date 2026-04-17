# ANSI colors
GREEN=$'\033[32m'
YELLOW=$'\033[33m'
RED=$'\033[31m'
CYAN=$'\033[36m'
MAGENTA=$'\033[35m'
DIM=$'\033[2m'
BOLD=$'\033[1m'
RESET=$'\033[0m'

draw_layout() {
  local c1="$1" c2="$2" c3="$3" info1="$4" info2="$5" w="${6:-24}"

  # Separator: subtle vertical divider between cat and info
  local sep="${DIM}│${RESET}"

  printf '%s %s %s\n' "$c1" "$sep" "$info1"
  printf '%s %s %s\n' "$c2" "$sep" "$info2"
  printf '%s\n' "$c3"
}

render_bar() {
  local pct=$1
  local width=12
  local filled=$((pct * width / 100))
  local empty=$((width - filled))

  # Color based on severity
  local color="$GREEN"
  if [ "$pct" -ge 70 ]; then
    color="$RED"
  elif [ "$pct" -ge 50 ]; then
    color="$YELLOW"
  fi

  local bar=""
  for ((i = 0; i < filled; i++)); do
    bar="${bar}■"
  done
  for ((i = 0; i < empty; i++)); do
    bar="${bar}·"
  done

  echo "${color}${bar}${RESET}"
}
