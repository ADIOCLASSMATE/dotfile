draw_layout() {
  local c1="$1" c2="$2" c3="$3" info1="$4" info2="$5" w="${6:-24}"

  printf '%s %s\n' "$c1" "$info1"
  printf '%s %s\n' "$c2" "$info2"
  printf '%s\n' "$c3"
}

render_bar() {
  local pct=$1
  local width=10
  local filled=$((pct * width / 100))
  local empty=$((width - filled))

  local bar=""

  for ((i = 0; i < filled; i++)); do
    bar="${bar}█"
  done
  for ((i = 0; i < empty; i++)); do
    bar="${bar}░"
  done

  echo "$bar"
}
