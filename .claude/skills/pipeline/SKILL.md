---
name: pipeline
description: >-
  Multi-agent pipeline: Lead implements → Critic reviews → Lead rebuttals → Critic verifies loop.
  Main agent acts as pipeline-lead AND executor, with critic as the quality gate.
  TRIGGER when: Plan Mode is approved and /pipeline is invoked.
  DO NOT TRIGGER when: task is a simple fix, single-line change, or user says "just do it."
---

# Pipeline — Lead-Implements, Critic-Reviews

Run a structured implement-review-rebuttal loop. The **main agent** acts as pipeline-lead AND executor — you implement code yourself. The **critic** (opus subagent) assesses your work holistically: does it achieve the plan's goals? Is the approach right for this repo? What was missed? Code quality is a safety net, not the focus.

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
  |-- 1. Copy approved plan VERBATIM from .claude/plans/ to .pipeline/<slug>/plan.md
  |     - Do NOT rewrite, summarize, or modify
  |-- 2. Derive task slug, create .pipeline/<slug>/
  |-- 3. Write implementation order to .pipeline/<slug>/state.md (think before you code)
  |     - Use the state.md template in File Protocol below
  |     - Track phases, dependencies, verification goals, and round history
  |
  |-- 4. Implement code yourself
  |-- 5. Run build/test/lint yourself
  |-- 6. Write implementation summary for Critic (.pipeline/<slug>/implementation-summary.md)
  |     - User requirement summary (1-3 sentences)
  |     - Plan highlights (or reference plan.md path)
  |     - Change list (file + what changed in each)
  |     - Key design decisions and rationale
  |     - Known tradeoffs / intentional non-standard patterns
  |
  |-- 7. Spawn critic (opus, pipeline-review mode)
  |     |-- Reads plan + implementation summary + changed files
  |     |-- Writes numbered feedback to .pipeline/<slug>/critic-feedback.md
  |
  |-- 8. Read .pipeline/<slug>/critic-feedback.md, write rebuttal
  |     - ACCEPT: fix the issue, include Diff Summary (which lines changed)
  |     - EXPLAIN: explain why it's not an issue
  |     - DEFER: record as follow-up (MEDIUM/LOW only; CRITICAL/HIGH cannot be deferred)
  |     - Actually fix all ACCEPT issues
  |     - Append Lead Rebuttal section to .pipeline/<slug>/critic-feedback.md
  |
  |-- 9. Spawn critic (opus, pipeline-verify mode)
  |     |-- Reads .pipeline/<slug>/critic-feedback.md with your rebuttal
  |     |-- Verifies fixes via Diff Summary locations
  |     |-- Appends Critic Verdict + Round Verdict
  |
  |-- 10. If FAIL → fix remaining issues, append Round N Changes to .pipeline/<slug>/implementation-summary.md, loop
  |-- 11. If PASS → relay final result to user
  |
  |-- (If same issue REJECTED 2 rounds in a row → spawn loop-operator)
```

## Task Slug

When `/pipeline` is triggered, derive a kebab-case slug from the task description (max 4 words). This slug namespaces all state files so multiple pipeline runs don't conflict.

**Slug generation**: lower-case, hyphen-separated, max 4 significant words. Strip filler words ("the", "a", "to", "with", "for", "and", "of").

| Task description | Slug |
|-----------------|------|
| "Add 8 skills to Claude Code" | `add-skills` |
| "Harden gateguard hook" | `harden-gateguard` |
| "Fix auth bug in login flow" | `fix-auth-bug` |
| "Refactor payment processing" | `refactor-payment` |

All pipeline state is written to `.pipeline/<slug>/`. The slug is included in every agent brief so downstream agents (critic, loop-operator) know which directory to use.

## How to Run

When this skill is triggered, **you (the main agent) become the pipeline-lead AND executor**. You implement code yourself, then spawn the critic to review.

1. Read the approved plan from `.claude/plans/`
2. Copy the approved plan **verbatim** to `.pipeline/<slug>/plan.md` — do NOT rewrite, summarize, or modify
3. Derive a task slug from the description
4. Create `.pipeline/<slug>/` directory at the **git repository root** (`git rev-parse --show-toplevel`), not the current working directory
5. Write implementation order to `.pipeline/<slug>/state.md` using the template in File Protocol below
6. Implement the code yourself
7. Run build/test/lint yourself
8. Write `.pipeline/<slug>/implementation-summary.md` for the Critic
9. Spawn `critic` (pipeline-review mode) with this brief:

   ```text
   Mode: pipeline-review
   Slug: <slug>

   Review the implementation against the plan at .pipeline/<slug>/plan.md.
   Read the implementation summary at .pipeline/<slug>/implementation-summary.md.
   Write your feedback to .pipeline/<slug>/critic-feedback.md.
   ```
10. Read `.pipeline/<slug>/critic-feedback.md`, write your rebuttal (append Lead Rebuttal section)
11. Spawn `critic` (pipeline-verify mode) with this brief:

    ```text
    Mode: pipeline-verify
    Slug: <slug>

    Read the review conversation at .pipeline/<slug>/critic-feedback.md.
    Verify all ACCEPT fixes at the Diff Summary locations.
    Append your Critic Verdict and Round Verdict.
    ```
12. If FAIL → fix issues, append `## Round N Changes` to implementation-summary.md, loop
13. If PASS → relay result to user

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

All pipeline state is stored in `.pipeline/<slug>/` at the **git repository root** (`git rev-parse --show-toplevel`), not the current working directory. This ensures consistent location regardless of where you `cd`.

| File | Written by | Purpose |
|------|-----------|---------|
| `plan.md` | Lead | **Verbatim copy** of the approved plan from `.claude/plans/`. Do NOT rewrite, summarize, or modify. The critic must review against the exact plan the user approved. |
| `state.md` | Lead | Current round status + implementation order. Use the template below. |
| `implementation-summary.md` | Lead | Intent input for Critic (requirements + changes + decisions). Round 2+: append `## Round N Changes` |
| `critic-feedback.md` | Critic (writes) + Lead (appends rebuttal) | Conversation-style review record |

### state.md Template

```markdown
# State — <slug>

## Current Round
Round [N] / 3 — [IN PROGRESS]

## Implementation Order
| # | Phase | Scope | Status | Verification |
|---|-------|-------|--------|-------------|
| 1 | [phase name] | [files/dirs affected] | pending | [what to verify — goal, not specific commands] |
| 2 | [phase name] | [files/dirs affected] | pending | [what to verify] |

## Dependencies
- Phase X blocks Phase Y: [reason — what must exist before Y can start]
- Phases A, B, C are independent

## Round History
| Round | Result | Score | Resolved | Deferred |
|-------|--------|-------|----------|----------|
| 1 | FAIL/PASS | X.X | N/M | N/M |
```

**Design principles**:
- **Language-agnostic**: No assumptions about programming language or build tools
- **Verification is a goal**: Write "all YAML frontmatter valid" not "npm test". Specific commands are decided at execution time.
- **Round History** is filled in as rounds complete — single-round pipelines won't need it.

**implementation-summary.md multi-round rule**:
- Round 1: Lead writes full summary (requirements + change list + design decisions + tradeoffs)
- Round 2+: Lead appends `## Round N Changes` section at the end — extra changes and new design decisions only. Do NOT rewrite the entire file.
- Critic sees: complete original intent + incremental per-round changes.

**critic-feedback.md conversation format**:

One file records the entire review conversation. Each round follows this structure:

```markdown
## Round 1

### Critic Feedback

#### Overall Assessment
[3-5 sentences: Does the implementation achieve the plan's goals? What's the biggest risk or omission? Is the approach appropriate for this repo?]

**Verdict: FAIL** | Weighted Score: 6.2/10

| # | Severity | Location | Issue | Fix | Effort |
|---|----------|----------|-------|-----|--------|
| R1-C1 | CRITICAL | auth.ts:42 | SQL injection | Use parameterized query | MEDIUM |
| R1-C2 | HIGH | user.ts:15 | Missing null check | Add guard clause | SMALL |

#### Scores

| Dimension | Score | Weight | Weighted |
|-----------|-------|--------|----------|
| Goal Alignment | 5/10 | 0.25 | 1.25 |
| Approach Quality | 7/10 | 0.20 | 1.40 |
| Impact & Completeness | 8/10 | 0.15 | 1.20 |
| Security | 3/10 | 0.15 | 0.45 |
| Code Quality | 7/10 | 0.10 | 0.70 |
| Consistency | 7/10 | 0.10 | 0.70 |
| Test Coverage | 6/10 | 0.05 | 0.30 |
| **TOTAL** | | | **6.00/10** |

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

Write to `.pipeline/<slug>/implementation-summary.md` before spawning Critic.

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
| `eval-harness` | Critic may invoke eval-harness for formal pass@k measurement when needed. |
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
