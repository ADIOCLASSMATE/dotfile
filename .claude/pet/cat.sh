ANIM_DIR="$HOME/.claude/pet/anims"

get_state() {
  local pct=$1
  if [ "$pct" -lt 30 ]; then
    echo "calm"
  elif [ "$pct" -lt 70 ]; then
    echo "active"
  else
    echo "panic"
  fi
}

get_frame() {
  local pct=$1 state=$2
  local anim_file="$ANIM_DIR/${state}.anim"
  local total
  total=$(($(grep -c '.' "$anim_file") - 1)) # minus 1 for W= header; grep -c '.' skips trailing blank lines
  local speed=$(((100 - pct) / 20 + 1))
  echo $(($(date +%s) / speed % total))
}

render_cat() {
  local state=$1 frame=$2
  local anim_file="$ANIM_DIR/${state}.anim"

  # line 1 = W= header, frames start at line 2
  local line
  line=$(sed -n "$((frame + 2))p" "$anim_file")

  local IFS='|'
  read -r L1 L2 L3 <<<"$line"

  local W
  W=$(sed -n '1p' "$anim_file" | cut -d= -f2)

  printf "%-${W}s\n" "$L1"
  printf "%-${W}s\n" "$L2"
  printf "%-${W}s\n" "$L3"
  # output W as last line for caller
  echo "$W"
}
