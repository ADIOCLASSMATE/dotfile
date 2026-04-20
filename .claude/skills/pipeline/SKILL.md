---
name: pipeline
description: >-
  Multi-agent pipeline: Plan → Execute → Review loop.
  Main agent becomes pipeline-lead and orchestrates pipeline-executor and
  pipeline-critic in an iterative quality-gated loop.
  TRIGGER when: Plan Mode is approved and /pipeline is invoked.
  DO NOT TRIGGER when: task is a simple fix, single-line change, or user says "just do it."
---

# Pipeline — Multi-Agent Orchestration

Run a structured plan-execute-review loop. The **main agent** acts as pipeline-lead and directly spawns executor and critic subagents.

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
YOU (main agent) become pipeline-lead
  |-- Read approved plan from .claude/plans/
  |-- Spawn pipeline-executor (subagent, sonnet)
  |     |
  |     v
  |   pipeline-executor (sonnet, Read + Write + Edit + Bash + Grep + Glob)
  |     |-- Implements code per plan
  |     |-- Runs build/test/lint
  |     |-- Reports what was built
  |     |
  |-- Spawn pipeline-critic (subagent, opus)
  |     |
  |     v
  |   pipeline-critic (opus, Read + Grep + Glob + Bash + Agent)
  |     |-- Reviews against plan
  |     |-- Scores quality
  |     |-- Returns PASS or FAIL with feedback
  |     |
  |-- If FAIL → feed feedback to executor, loop (max 3x)
  |-- If PASS → relay final result to user
  |-- If stalled → spawn loop-operator for diagnosis
```

## How to Run

When this skill is triggered, **you (the main agent) become the pipeline-lead**. Do NOT spawn a separate pipeline-lead agent — that role is yours.

1. Read the approved plan from `.claude/plans/`
2. Decide execution strategy: parallel or sequential (see agents.md)
3. Spawn `pipeline-executor` with a detailed, self-contained brief
4. After executor completes, spawn `pipeline-critic` to review
5. If FAIL → synthesize critic feedback into concrete improvements, spawn executor again
6. If PASS → relay result to user

## Pipeline Modes

### Standard (default)

Full plan-execute-review loop for feature implementation:

```text
pipeline-lead (you) → pipeline-executor → pipeline-critic → loop if needed
```

### Research-Only

For investigations and analysis where no code changes are needed:

```text
pipeline-lead (you) — research only, no executor delegation
```

Research and return findings without starting the execution loop.

### Quick-Fix

For small but non-trivial changes that still benefit from review:

```text
pipeline-lead (you) → pipeline-executor (single pass) → pipeline-critic (verification-only mode)
```

One iteration, no loop. Faster but lower quality assurance.

## File Protocol

All pipeline state is stored in `.pipeline/` at the project root:

| File | Written by | Purpose |
|------|-----------|---------|
| `plan.md` | pipeline-lead (you) | Implementation plan with phases and success criteria |
| `state.md` | pipeline-lead (you) | Current iteration status and next action |
| `executor-report.md` | pipeline-executor | What was built, changed, and known issues |
| `critic-feedback.md` | pipeline-critic | Verdict, scores, and specific issues |

Clean up `.pipeline/` between unrelated tasks.

## Executor Brief Rules

Subagents have NO access to your conversation history. Every brief must:

1. **Be self-contained** — include ALL information the executor needs
2. **Specify exact file paths** — list every file to CREATE/MODIFY
3. **Define file boundaries** for parallel execution — CREATE / MODIFY / READ ONLY / DO NOT TOUCH
4. **Include relevant code context** — paste function signatures, type definitions, API contracts
5. **Specify verification commands** — how to confirm the work is correct

See `~/.claude/rules/common/agents.md` for full executor brief format.

## Iteration Limits

- **Maximum 3 executor→critic cycles** per pipeline run
- After 3 cycles, return results even if not all criteria pass
- If stalled for 2 consecutive iterations, spawn loop-operator

## Pipeline-Lead Discipline

When acting as pipeline-lead, you MUST NOT:
- Write or edit source code — that is the executor's job
- Run build/test commands — that is the executor's job
- Evaluate quality yourself — that is the critic's job
- Fall back to direct execution if pipeline fails — report to user instead

## Integration with Existing Skills

| Skill | Relationship |
|-------|-------------|
| `council` | Use for decision-making, not code quality. Pipeline and council serve different purposes. |
| `eval-harness` | Pipeline-critic may invoke eval-harness for formal pass@k measurement when needed. |
| `tdd-workflow` | Pipeline-executor follows TDD when the project requires it (write tests first). |
| `search-first` | Pipeline-lead uses search-first principles during research phase. |

## Examples

### Feature implementation

```
/pipeline Add user authentication with OAuth2 and session management
```

You research auth patterns in the codebase, plan the implementation, spawn executor with detailed brief, spawn critic to review, loop until quality gates pass.

### Refactoring

```
/pipeline Extract the payment processing logic into a separate service
```

You map all dependencies, plan extraction order, executor implements phase by phase, critic checks for regressions.

### Bug investigation

```
/pipeline --mode=research-only Investigate why the WebSocket connection drops under load
```

You research the WebSocket implementation, identify likely causes, return findings without starting the execution loop.

## Anti-Patterns

- Running pipeline for trivial changes (wastes context and time)
- Skipping the research phase (leads to plans that don't fit the codebase)
- Ignoring critic feedback (defeats the purpose of the loop)
- Running more than 3 iterations (diminishing returns, should reduce scope instead)
- Mixing pipeline with manual edits mid-loop (confuses state tracking)
- Spawning pipeline-lead as a subagent (it doesn't exist — you ARE the lead)
