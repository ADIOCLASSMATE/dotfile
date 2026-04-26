# Implementation Summary

## User Requirement
Harden the gateguard-fact-force.js hook and coding-style.md Check Response section so that when hooks fire, the model must respond with tool-based evidence (Glob/Grep/Read results) instead of vague confirmations like "confirmed, no issues found". If issues are found, the model must fix them before proceeding.

## Plan Reference
No formal plan.md — user approved two specific changes inline:
1. Rewrite gateguard-fact-force.js Check messages to require specific tool calls
2. Change coding-style.md Check Response format from "brief one-line answer" to "tool-based evidence"

## Changes

| File | What Changed |
|------|-------------|
| `.claude/scripts/hooks/gateguard-fact-force.js` | Rewrote all 4 Check message functions (`destructiveBashMsg`, `deletionAdviceMsg`, `newFileAdviceMsg`, `largeEditAdviceMsg`) to require specific tool calls (Grep/Glob/Read) and mandate fixes when issues found. Updated JSDoc header to reflect new behavior. |
| `.claude/rules/common/coding-style.md` | Replaced `## Check Response (CRITICAL)` section — changed format from "brief one-line answer" to "tool-based evidence". Added rule that vague confirmations without tool results are NOT acceptable. Added rule that if a check reveals an issue, model MUST fix before proceeding. Updated example to show Glob/Grep-based evidence. |

## Design Decisions
1. **MUST language in hook messages**: Used "You MUST" instead of "please confirm" to make the requirement unambiguous. Models are more likely to comply with imperative instructions than with requests.
2. **Specific tool names in messages**: Named Glob, Grep, Read explicitly so the model knows exactly what tool to call, rather than vaguely asking to "search" or "verify".
3. **Mandatory fix-before-proceed**: Added "you MUST fix BEFORE proceeding" clauses to prevent the model from noting an issue and then ignoring it.
4. **Kept exit code 0 (allow)**: Did not change to blocking (exit code 2). The hook remains advisory — it cannot force tool calls, but the coding-style.md rule now makes tool-based evidence mandatory at the rules level. This two-layer approach (hook message + rule) is more robust than blocking alone, since blocking would just prevent the action without requiring evidence.

## Known Tradeoffs
- **Hook messages are longer**: Each Check message went from 2-3 bullets to 3-4 bullets with explicit tool instructions. This adds ~50-100 tokens per Check to context. Acceptable because Checks only fire on potentially risky operations (new files, large edits, deletions, destructive bash).
- **Model may still evade**: A determined model can still fabricate tool results in its response. The hook cannot verify that the model actually called the tools. However, the coding-style.md rule + explicit tool name requirements make evasion much harder and more obvious.
- **No exit code 2 blocking**: User discussed but did not request blocking. Advisory approach with stronger wording chosen instead.
