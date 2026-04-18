---
name: pipeline
description: >-
  Multi-agent pipeline: Research → Execute → Review loop.
  Triggers pipeline-lead which orchestrates pipeline-executor and pipeline-critic
  in an iterative quality-gated loop. Replaces blueprint, continuous-agent-loop,
  and development-workflow.
  TRIGGER when: user requests a non-trivial feature, refactor, or investigation
  that benefits from plan-execute-review iteration.
  DO NOT TRIGGER when: task is a simple fix, single-line change, or user says "just do it."
---

# Pipeline — Multi-Agent Orchestration

Run a structured plan-execute-review loop using three specialized agents.

## When to Use

- Implementing a non-trivial feature (multiple files, new components)
- Refactoring that spans multiple modules
- Bug investigation requiring research before fix
- Any task where plan-then-execute beats trial-and-error

**Do not use** for:
- Simple fixes (1-2 files, obvious change)
- Tasks where the user says "just do it"
- Quick lookups or explanations

## Architecture

```text
/pipeline [task description]
  |
  v
pipeline-lead (opus, read-only + delegate)
  |-- Research codebase, write plan
  |-- Delegate to pipeline-executor
  |     |
  |     v
  |   pipeline-executor (sonnet, full tools)
  |     |-- Implements code
  |     |-- Runs build/test/lint
  |     |-- Reports what was built
  |     |
  |-- Delegate to pipeline-critic
  |     |
  |     v
  |   pipeline-critic (opus, read + bash + agent)
  |     |-- Reviews against plan
  |     |-- Scores quality
  |     |-- Returns PASS or FAIL with feedback
  |     |
  |-- If FAIL → extract improvements, loop back to executor
  |-- If PASS → return final result
  |-- If stalled → call loop-operator for diagnosis
```

## How to Run

When this skill is triggered, call the pipeline-lead agent:

```
Agent(subagent_type="pipeline-lead", prompt="[task description from user]")
```

The pipeline-lead handles all orchestration. You do not need to manage the loop yourself.

## Pipeline Modes

### Standard (default)

Full plan-execute-review loop for feature implementation:

```
pipeline-lead → pipeline-executor → pipeline-critic → loop if needed
```

### Research-Only

For investigations and analysis where no code changes are needed:

```
pipeline-lead (research only, no executor delegation)
```

The lead researches and returns findings without starting the execution loop.

### Quick-Fix

For small but non-trivial changes that still benefit from review:

```
pipeline-lead → pipeline-executor (single pass) → pipeline-critic (verification-only mode)
```

One iteration, no loop. Faster but lower quality assurance.

## File Protocol

All pipeline state is stored in `.claude/pipeline/`:

| File | Written by | Purpose |
|------|-----------|---------|
| `plan.md` | pipeline-lead | Implementation plan with phases and success criteria |
| `state.md` | pipeline-lead | Current iteration status and next action |
| `executor-report.md` | pipeline-executor | What was built, changed, and known issues |
| `critic-feedback.md` | pipeline-critic | Verdict, scores, and specific issues |

Clean up `.claude/pipeline/` between unrelated tasks.

## Iteration Limits

- **Maximum 3 executor→critic cycles** per pipeline run
- After 3 cycles, return results even if not all criteria pass
- If stalled for 2 consecutive iterations, pipeline-lead calls loop-operator

## Integration with Existing Skills

| Skill | Relationship |
|-------|-------------|
| `council` | Use for decision-making, not code quality. Pipeline and council serve different purposes. |
| `eval-harness` | Pipeline-critic may invoke eval-harness for formal pass@k measurement when needed. |
| `tdd-workflow` | Pipeline-executor follows TDD when the project requires it (write tests first). |
| `search-first` | Pipeline-lead uses search-first principles during research phase. |
| `agentic-engineering` | Model tier routing is already built into the pipeline agents (opus for lead/critic, sonnet for executor). |

## Examples

### Feature implementation

```
/pipeline Add user authentication with OAuth2 and session management
```

Pipeline-lead researches auth patterns in the codebase, plans the implementation, delegates to executor, gets reviewed by critic, loops until quality gates pass.

### Refactoring

```
/pipeline Extract the payment processing logic into a separate service
```

Pipeline-lead maps all dependencies, plans extraction order, executor implements phase by phase, critic checks for regressions.

### Bug investigation

```
/pipeline --mode=research-only Investigate why the WebSocket connection drops under load
```

Pipeline-lead researches the WebSocket implementation, identifies likely causes, returns findings without starting the execution loop.

## Anti-Patterns

- Running pipeline for trivial changes (wastes context and time)
- Skipping the research phase (leads to plans that don't fit the codebase)
- Ignoring critic feedback (defeats the purpose of the loop)
- Running more than 3 iterations (diminishing returns, should reduce scope instead)
- Mixing pipeline with manual edits mid-loop (confuses state tracking)
