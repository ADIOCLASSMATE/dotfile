#!/bin/bash
# Setup: append ExitPlanMode PostToolUse hook to ~/.claude/settings.json
#
# Idempotent — safe to rerun. Backs up the original before modifying.
#
# Usage:
#   bash ~/.claude/scripts/setup-hooks.sh
#
# Prerequisites:
#   - jq (brew install jq / apt install jq)
#   - ~/.claude/settings.json must exist

set -euo pipefail

SETTINGS_FILE="$HOME/.claude/settings.json"
HOOK_SCRIPT="$HOME/.claude/scripts/hooks/on-plan-accepted.js"
MATCHER="ExitPlanMode"

# ── Preflight checks ───────────────────────────────────────────────────

if ! command -v jq &>/dev/null; then
  echo "Error: jq is required but not installed."
  echo "Install it: brew install jq  (macOS)  or  apt install jq  (Linux)"
  exit 1
fi

if [[ ! -f "$SETTINGS_FILE" ]]; then
  echo "Error: $SETTINGS_FILE not found."
  echo "Create it first with your API tokens and base hook config (see CLAUDE.md Step 3)."
  exit 1
fi

if [[ ! -f "$HOOK_SCRIPT" ]]; then
  echo "Error: $HOOK_SCRIPT not found."
  echo "Make sure ~/.claude is symlinked to the dotfile repo and you are on the correct branch."
  exit 1
fi

# ── Check if already configured ─────────────────────────────────────────

EXISTING=$(jq -r '.hooks.PostToolUse // [] | map(select(.matcher == "'"$MATCHER"'")) | length' "$SETTINGS_FILE" 2>/dev/null || echo "0")

if [[ "$EXISTING" -gt 0 ]]; then
  echo "Already configured: PostToolUse hook with matcher '$MATCHER' exists in $SETTINGS_FILE"
  echo "No changes needed."
  exit 0
fi

# ── Backup ──────────────────────────────────────────────────────────────

BACKUP_DIR="$HOME/.claude-backups"
mkdir -p "$BACKUP_DIR"
BACKUP="$BACKUP_DIR/settings.json.bak.$(date +%Y%m%d_%H%M%S)"
cp "$SETTINGS_FILE" "$BACKUP"
echo "Backed up to: $BACKUP (outside repo)"

# ── Merge new hook entry ────────────────────────────────────────────────

NEW_HOOK=$(cat <<'JQ'
{
  "matcher": $matcher,
  "hooks": [
    {
      "type": "command",
      "command": $command,
      "timeout": 10
    }
  ]
}
JQ
)

jq \
  --arg matcher "$MATCHER" \
  --arg command "node $HOOK_SCRIPT" \
  '.hooks.PostToolUse = (.hooks.PostToolUse // []) + ['"$NEW_HOOK"']' \
  "$SETTINGS_FILE" > "$SETTINGS_FILE.tmp"

mv "$SETTINGS_FILE.tmp" "$SETTINGS_FILE"

# ── Verify ──────────────────────────────────────────────────────────────

VERIFY=$(jq -r '.hooks.PostToolUse | map(select(.matcher == "'"$MATCHER"'")) | length' "$SETTINGS_FILE")

if [[ "$VERIFY" -gt 0 ]]; then
  echo "Done. PostToolUse hook '$MATCHER' added to $SETTINGS_FILE"
  echo "The hook will inject a /pipeline reminder after every plan approval."
else
  echo "Error: hook was not added correctly. Restore from backup: cp $BACKUP $SETTINGS_FILE"
  exit 1
fi
