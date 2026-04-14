#!/bin/zsh

input=$(cat)

MODEL=$(echo "$input" | jq -r '.model.display_name')
DIR=$(echo "$input" | jq -r '.workspace.current_dir')
COST=$(echo "$input" | jq -r '.cost.total_cost_usd // 0')
PCT=$(echo "$input" | jq -r '.context_window.used_percentage // 0' | cut -d. -f1)

# load modules
source ~/.claude/pet/utils.sh
source ~/.claude/pet/cat.sh
source ~/.claude/pet/render.sh

STATE=$(get_state "$PCT")
FRAME=$(get_frame "$PCT" "$STATE")

CAT=("${(@f)$(render_cat "$STATE" "$FRAME")}")
CAT1="${CAT[1]}"
CAT2="${CAT[2]}"
CAT3="${CAT[3]}"
CAT_W="${CAT[4]}"

BAR=$(render_bar "$PCT")
COST_FMT=$(printf '$%.2f' "$COST")

INFO1="[${MODEL}] 📂 ${DIR##*/}"
INFO2="${BAR} ${PCT}% | ${COST_FMT}"

draw_layout "$CAT1" "$CAT2" "$CAT3" "$INFO1" "$INFO2" "$CAT_W"
