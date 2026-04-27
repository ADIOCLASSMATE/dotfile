---
name: critic
description: >-
  Standalone code review using the critic agent. One-shot review for code quality,
  security, and correctness. TRIGGER when: user asks for code review outside the
  pipeline, says "review this code," or wants a quick quality check.
  DO NOT TRIGGER when: inside a pipeline loop (pipeline spawns critic internally).
---

# /critic — Standalone Code Review

Invoke the critic agent in standalone mode for one-shot code review outside the pipeline.

## When to Use

- User asks for a code review ("review this", "check my code", "is this good?")
- After writing or modifying code and wanting a quality check
- Before committing to shared branches
- When security-sensitive code is changed (auth, payments, user data)
- Quick quality assessment without the full pipeline loop

## When NOT to Use

- Inside a pipeline loop — pipeline spawns critic internally (pipeline-review / pipeline-verify modes)
- For simple fixes (1-2 lines, obvious change) — just do it
- For architectural decisions — use `/council`
- For implementation planning — use Plan Mode

## How to Run

1. Gather context: run `git diff --staged` and `git diff` to see changes. If the user specified files, read those instead.
2. Spawn the critic agent in **standalone mode**:

```text
Review the following code for quality, security, and correctness.

Mode: standalone
Files to review: [list file paths or describe diff range]
Focus areas: [optional — security, architecture, all]

Use S-C[X] numbering for issues. Output directly to conversation (not to .pipeline/<slug>/).
```

3. The critic writes directly to the conversation. No rebuttal loop. No file output.

## Output

The critic returns a weighted score (Goal Alignment, Approach Quality, Impact & Completeness, Security, Code Quality, Consistency, Test Coverage) with specific issues numbered S-C1, S-C2, etc. Each issue includes severity (CRITICAL/HIGH/MEDIUM/LOW), location, and a concrete fix.

In standalone mode, Goal Alignment is assessed against the code's stated purpose, the caller's review brief, or the apparent intent of the changes — there is no formal plan.

## Relationship to Pipeline

| | `/critic` | `/pipeline` |
|---|----------|------------|
| Trigger | Direct user request | Plan approved |
| Loop | One-shot review | implement → review → rebuttal → verify (max 3 rounds) |
| Critic mode | standalone | pipeline-review + pipeline-verify |
| Output | Direct to conversation | `.pipeline/<slug>/critic-feedback.md` |

The pipeline uses the same critic agent internally. `/critic` is the standalone entry point for quick reviews.

## Anti-Patterns

- Using `/critic` when `/pipeline` is the right tool (plan was approved)
- Expecting a rebuttal loop — standalone is one-shot, no back-and-forth
- Reviewing without providing file paths or diff context
- Spawning critic directly instead of using this skill (the skill handles context gathering)
