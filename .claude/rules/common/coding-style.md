# Coding Style

## Immutability (CRITICAL)

ALWAYS create new objects, NEVER mutate existing ones:

```
// Pseudocode
WRONG:  modify(original, field, value) → changes original in-place
CORRECT: update(original, field, value) → returns new copy with change
```

Rationale: Immutable data prevents hidden side effects, makes debugging easier, and enables safe concurrency.

## Core Principles

### KISS (Keep It Simple)

- Prefer the simplest solution that actually works
- Avoid premature optimization
- Optimize for clarity over cleverness

### DRY (Don't Repeat Yourself)

- Extract repeated logic into shared functions or utilities
- Avoid copy-paste implementation drift
- Introduce abstractions when repetition is real, not speculative

### YAGNI (You Aren't Gonna Need It)

- Do not build features or abstractions before they are needed
- Avoid speculative generality
- Start simple, then refactor when the pressure is real

## File Organization

MANY SMALL FILES > FEW LARGE FILES:
- High cohesion, low coupling
- 200-400 lines typical, 800 max
- Extract utilities from large modules
- Organize by feature/domain, not by type

## Error Handling

ALWAYS handle errors comprehensively:
- Handle errors explicitly at every level
- Provide user-friendly error messages in UI-facing code
- Log detailed error context on the server side
- Never silently swallow errors

## Input Validation

ALWAYS validate at system boundaries:
- Validate all user input before processing
- Use schema-based validation where available
- Fail fast with clear error messages
- Never trust external data (API responses, user input, file content)

## Naming Conventions

- Variables and functions: `camelCase` with descriptive names
- Booleans: prefer `is`, `has`, `should`, or `can` prefixes
- Interfaces, types, and components: `PascalCase`
- Constants: `UPPER_SNAKE_CASE`
- Custom hooks: `camelCase` with a `use` prefix

## Code Smells to Avoid

### Deep Nesting

Prefer early returns over nested conditionals once the logic starts stacking.

### Magic Numbers

Use named constants for meaningful thresholds, delays, and limits.

### Long Functions

Split large functions into focused pieces with clear responsibilities.

## Check Response (CRITICAL)

When a `[Check]` message appears from the hook system before a write/edit/delete/bash operation, you MUST respond to every bullet point BEFORE performing the action. Do not skip or silently ignore any check.

Format: address each bullet with a brief one-line answer, then proceed.

Example:
```
[Check] Creating new file: utils/format.ts
- Confirm no existing file serves the same purpose.
- Ensure this file will actually be used.

→ No existing formatter utility found (Glob `**/format*` returns no matches).
→ Will be imported by UserCard.ts and ProfilePage.ts.
```

If you cannot answer a check item confidently, stop and investigate first.

## Anti-Silent-Assumption

Don't hide confusion or silently pick one interpretation:

- If multiple interpretations exist, present them all — don't pick silently
- If a simpler approach exists, say so. Push back when warranted
- If something is unclear, stop. Name what's confusing and ask

## Multi-Step Verification

For multi-step tasks, state a brief plan with verification at each step:

```
1. [Step] → verify: [check]
2. [Step] → verify: [check]
3. [Step] → verify: [check]
```

Strong success criteria let you loop independently. Weak criteria ("make it work") require constant clarification.

## Code Quality Checklist

Before marking work complete:
- [ ] Code is readable and well-named
- [ ] Functions are small (<50 lines)
- [ ] Files are focused (<800 lines)
- [ ] No deep nesting (>4 levels)
- [ ] Proper error handling
- [ ] No hardcoded values (use constants or config)
- [ ] No mutation (immutable patterns used)

## Communication

- Prefer concise, actionable answers.
- When giving commands, prefer copy/paste-ready blocks.

## Safety

- Don't propose destructive commands unless explicitly requested.
- For risky operations (force-push, rm -rf, etc.), ask for confirmation first.

## Planning and Execution

- For any large plan, backup the plan to the project directory (e.g., `PLAN.md` or `.claude/plan.md`).
- When user explicitly requests continuous work, work autonomously without excessive confirmation requests.
- Prioritize execution over confirmation to save time and resources.
- Complete work first, summarize results, then let user review and provide feedback.

## Rules Working Indicators

These rules are working if you observe:
- Fewer unnecessary changes in diffs — only requested changes appear
- Fewer rewrites due to overcomplication — code is simple the first time
- Clarifying questions come before implementation — not after mistakes
- Clean, minimal PRs — no drive-by refactoring or "improvements"


