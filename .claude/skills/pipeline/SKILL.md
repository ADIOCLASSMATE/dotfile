---
name: pipeline
description: >-
  Multi-agent pipeline: Lead implements → Critic reviews → Lead rebuttals → Critic verifies loop.
  Main agent acts as pipeline-lead AND executor, with pipeline-critic as the quality gate.
  TRIGGER when: Plan Mode is approved and /pipeline is invoked.
  DO NOT TRIGGER when: task is a simple fix, single-line change, or user says "just do it."
---

# Pipeline — Lead-Implements, Critic-Reviews

Run a structured implement-review-rebuttal loop. The **main agent** acts as pipeline-lead AND executor — you implement code yourself. The **pipeline-critic** (opus subagent) reviews your work, and you rebuttal its feedback.

## When to Use

- After Plan Mode is approved (mandatory — see CLAUDE.md)
- Implementing a non-trivial feature (multiple files, new components)
- Refactoring that spans multiple modules
- Bug investigation requiring research before fix

**Do not use** for:
- Simple fixes (1-2 files, obvious change)
- Tasks where the user says "just do it"
- Quick lookups or explanations

## Architecture

```text
/pipeline [task description]
  |
  v
YOU (main agent) = Lead + Executor
  |
  |-- 1. Read approved plan from .claude/plans/
  |-- 2. Write implementation order to state.md (think before you code)
  |     - File modification order
  |     - Dependencies if 3+ files
  |     - Keep under 10 lines
  |
  |-- 3. Implement code yourself
  |-- 4. Run build/test/lint yourself
  |-- 5. Write implementation summary for Critic
  |     - User requirement summary (1-3 sentences)
  |     - Plan highlights (or reference plan.md path)
  |     - Change list (file + what changed in each)
  |     - Key design decisions and rationale
  |     - Known tradeoffs / intentional non-standard patterns
  |
  |-- 6. Spawn pipeline-critic (opus, review mode)
  |     |-- Reads plan + implementation summary + changed files
  |     |-- Writes numbered feedback to critic-feedback.md
  |
  |-- 7. Read critic-feedback.md, write rebuttal
  |     - ACCEPT: fix the issue, include Diff Summary (which lines changed)
  |     - EXPLAIN: explain why it's not an issue
  |     - DEFER: record as follow-up (MEDIUM/LOW only; CRITICAL/HIGH cannot be deferred)
  |     - Actually fix all ACCEPT issues
  |     - Append Lead Rebuttal section to critic-feedback.md
  |
  |-- 8. Spawn pipeline-critic (opus, verify mode)
  |     |-- Reads critic-feedback.md with your rebuttal
  |     |-- Verifies fixes via Diff Summary locations
  |     |-- Appends Critic Verdict + Round Verdict
  |
  |-- 9. If FAIL → fix remaining issues, append Round N Changes to implementation-summary.md, loop
  |-- 10. If PASS → relay final result to user
  |
  |-- (If same issue REJECTED 2 rounds in a row → spawn loop-operator)
```

## How to Run

When this skill is triggered, **you (the main agent) become the pipeline-lead AND executor**. You implement code yourself, then spawn the critic to review.

1. Read the approved plan from `.claude/plans/`
2. Write implementation order to `.pipeline/state.md` (think before you code)
3. Implement the code yourself
4. Run build/test/lint yourself
5. Write `.pipeline/implementation-summary.md` for the Critic
6. Spawn `pipeline-critic` (review mode) — pass implementation summary + plan path + changed files
7. Read `.pipeline/critic-feedback.md`, write your rebuttal (append Lead Rebuttal section)
8. Spawn `pipeline-critic` (verify mode) — pass critic-feedback.md path + implementation summary
9. If FAIL → fix issues, append `## Round N Changes` to implementation-summary.md, loop
10. If PASS → relay result to user

## Pipeline Modes

### Standard (default)

Full implement-review-rebuttal-verify loop:

```text
Lead implements → Critic reviews → Lead rebuttals → Critic verifies → loop if needed
```

### Research-Only

For investigations and analysis where no code changes are needed:

```text
Lead — research only, no implementation, no Critic
```

Research and return findings without starting the review loop.

## File Protocol

All pipeline state is stored in `.pipeline/` at the project root:

| File | Written by | Purpose |
|------|-----------|---------|
| `plan.md` | Lead | Implementation plan with phases and success criteria |
| `state.md` | Lead | Current round status + implementation order (lightweight) |
| `implementation-summary.md` | Lead | Intent input for Critic (requirements + changes + decisions). Round 2+: append `## Round N Changes` |
| `critic-feedback.md` | Critic (writes) + Lead (appends rebuttal) | Conversation-style review record |

**implementation-summary.md multi-round rule**:
- Round 1: Lead writes full summary (requirements + change list + design decisions + tradeoffs)
- Round 2+: Lead appends `## Round N Changes` section at the end — extra changes and new design decisions only. Do NOT rewrite the entire file.
- Critic sees: complete original intent + incremental per-round changes.

**critic-feedback.md conversation format**:

One file records the entire review conversation. Each round follows this structure:

```markdown
## Round 1

### Critic Feedback
**Verdict: FAIL** | Weighted Score: 6.2/10

| # | Severity | Location | Issue | Fix | Effort |
|---|----------|----------|-------|-----|--------|
| R1-C1 | CRITICAL | auth.ts:42 | SQL injection | Use parameterized query | MEDIUM |
| R1-C2 | HIGH | user.ts:15 | Missing null check | Add guard clause | SMALL |

#### Scores

| Dimension | Score | Weight | Weighted |
|-----------|-------|--------|----------|
| Functionality | 5/10 | 0.20 | 1.0 |
| Code Quality | 7/10 | 0.15 | 1.05 |
| Security | 3/10 | 0.15 | 0.45 |
| Architecture | 8/10 | 0.15 | 1.2 |
| Impact Analysis | 8/10 | 0.15 | 1.2 |
| Consistency | 7/10 | 0.10 | 0.7 |
| Test Coverage | 6/10 | 0.10 | 0.6 |
| **TOTAL** | | | **6.2/10** |

### Lead Rebuttal
| Issue | Response | Action | Diff Summary |
|-------|----------|--------|--------------|
| R1-C1 | ACCEPT | Fixed | auth.ts:42-45: replaced raw SQL with parameterized query |
| R1-C2 | EXPLAIN | Not an issue | This field is validated upstream at API gateway |

### Critic Verdict
| Issue | Verdict | Note |
|-------|---------|------|
| R1-C1 | FIXED | Verified: parameterized query now used |
| R1-C2 | ACCEPTED | Valid — upstream validation confirmed |

**Round Verdict: PASS** | Weighted Score: 8.1/10

---

## Round 2
...
```

## Rebuttal Actions

When writing your rebuttal, use these three actions for each issue:

| Action | When | What to do |
|--------|------|------------|
| ACCEPT | Issue is valid | Fix the code, describe what changed in Diff Summary column |
| EXPLAIN | Issue is a false positive | Explain why it's not an issue (tradeoff, upstream guarantee, etc.) |
| DEFER | Issue exists but out of scope | Only for MEDIUM/LOW. CRITICAL/HIGH cannot be deferred — Critic will REJECT. |

**DEFER rule**: You may only DEFER MEDIUM and LOW severity issues. If you attempt to DEFER a CRITICAL or HIGH issue, the Critic will automatically REJECT it.

## Round and Loop Control

### Round definition

1 round = Critic review → Lead rebuttal + fixes → Critic verify

### Maximum rounds

3 rounds per pipeline run.

### Third round still FAIL

- Unresolved CRITICAL → report to user, do NOT auto-pass
- Only HIGH/MEDIUM → Lead decides whether acceptable, record in state.md, continue

### Loop-operator trigger

If the same issue (same issue number) is REJECTED by Critic for 2 consecutive rounds and you still disagree → spawn loop-operator for third-party arbitration.

## Implementation Summary Format

Write to `.pipeline/implementation-summary.md` before spawning Critic.

```markdown
# Implementation Summary

## User Requirement
[1-3 sentence summary of what the user asked for]

## Plan Reference
[Path to plan.md or inline the key points]

## Changes
| File | What Changed |
|------|-------------|
| src/auth/jwt.ts | Added JWT token generation and validation |
| src/middleware/auth.ts | Added auth middleware using JWT |
| tests/auth.test.ts | Added unit tests for JWT functions |

## Design Decisions
1. [Decision]: [Rationale]
2. [Decision]: [Rationale]

## Known Tradeoffs
- [Tradeoff]: [Why it's acceptable]
```

For Round 2+, append:

```markdown

---

## Round 2 Changes
| File | What Changed |
|------|-------------|
| src/auth/jwt.ts | Fixed token expiration check |

## New Design Decisions
- [Decision]: [Rationale]
```

## Pipeline-Lead Discipline

When acting as pipeline-lead:

- **DO** implement code yourself — you are the executor
- **DO** run build/test/lint yourself
- **DO NOT** evaluate your own code quality — that is the Critic's job
- **DO** write implementation summary before spawning Critic — Critic cannot read your mind
- **DO** write implementation order to state.md before coding — think before you write
- **DO** include Diff Summary in your rebuttal — Critic needs to locate your fixes
- **DO NOT** skip the Critic review — even if you think the code is perfect

## Integration with Existing Skills

| Skill | Relationship |
|-------|-------------|
| `council` | Use for decision-making, not code quality. Pipeline and council serve different purposes. |
| `eval-harness` | Pipeline-critic may invoke eval-harness for formal pass@k measurement when needed. |
| `tdd-workflow` | Lead follows TDD when the project requires it (write tests first). |
| `search-first` | Lead uses search-first principles during research phase. |

## Examples

### Feature implementation

```
/pipeline Add user authentication with OAuth2 and session management
```

You research auth patterns, plan implementation, write code, write implementation summary, spawn Critic to review, rebuttal its feedback, loop until PASS.

### Refactoring

```
/pipeline Extract the payment processing logic into a separate service
```

You map dependencies, write implementation order, implement extraction, spawn Critic to check for regressions and architectural issues.

### Bug investigation

```
/pipeline --mode=research-only Investigate why the WebSocket connection drops under load
```

You research the WebSocket implementation, identify likely causes, return findings without implementation or Critic review.

## Anti-Patterns

- Running pipeline for trivial changes (wastes context and time)
- Skipping the research phase (leads to plans that don't fit the codebase)
- Ignoring Critic feedback (defeats the purpose of the loop)
- Running more than 3 rounds (diminishing returns — reduce scope instead)
- Mixing pipeline with manual edits mid-loop (confuses state tracking)
- Spawning pipeline-lead as a subagent (it doesn't exist — you ARE the lead)
- Deferring CRITICAL/HIGH issues (Critic will REJECT)
- Skipping implementation summary (Critic will be blind-reviewing)
