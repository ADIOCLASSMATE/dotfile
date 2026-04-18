# Agent Orchestration

## Pipeline Agents (Primary Workflow)

For non-trivial tasks, use the pipeline. Triggered via `/pipeline` skill or by calling pipeline-lead directly.

```text
pipeline-lead (opus, read-only + delegate)
  |   Researches, plans, orchestrates the loop
  |
  +--→ pipeline-executor (sonnet, full tools)
  |      Implements code, runs build/test/lint
  |
  +--→ pipeline-critic (opus, read + bash + agent)
  |      Reviews, scores, returns PASS/FAIL
  |
  +--→ loop-operator (sonnet, read + edit + bash)
         Diagnoses stalls, recommends recovery
```

**Loop**: lead → executor → critic → (if FAIL) executor → critic → ... (max 3 cycles)
**Stall recovery**: If 2 consecutive iterations show no progress, lead calls loop-operator.

| Agent | Model | Tools | Role |
|-------|-------|-------|------|
| pipeline-lead | opus | Read, Grep, Glob, Agent | Orchestrate: research, plan, delegate, loop control |
| pipeline-executor | sonnet | All | Implement: write code, run verification, report results |
| pipeline-critic | opus | Read, Grep, Glob, Bash, Agent | Review: score quality, flag issues, PASS/FAIL verdict |
| loop-operator | sonnet | Read, Grep, Glob, Bash, Edit | Diagnose stalls and recommend recovery |

## Specialist Agents (On-Demand)

Use these when the pipeline delegates a specific concern, or when the task is narrow enough to not need the full pipeline:

| Agent | Purpose | When to Use |
|-------|---------|-------------|
| architect | System design | Architectural decisions (standalone, not as part of pipeline) |
| tdd-guide | Test-driven development | When pipeline-executor needs TDD guidance |
| security-reviewer | Security analysis | When pipeline-critic flags security concerns |
| build-error-resolver | Fix build errors | When executor hits a build failure |
| e2e-runner | E2E testing | When critic needs browser-based verification |
| refactor-cleaner | Dead code cleanup | Code maintenance |
| doc-updater | Documentation | Updating docs |

## When to Use Pipeline vs. Single Agent

| Situation | Use |
|-----------|-----|
| New feature spanning 3+ files | `/pipeline` |
| Refactor with unclear scope | `/pipeline` |
| Bug that needs investigation first | `/pipeline --mode=research-only`, then decide |
| Quick code review of existing changes | `pipeline-critic` directly |
| Fix a build error | `build-error-resolver` directly |
| Write tests for a known function | `tdd-guide` directly |
| Security audit | `security-reviewer` directly |
| Architectural decision (no code) | `architect` or `/council` |

## Parallel Task Execution

When the pipeline-lead delegates independent work, run agents in parallel:

```markdown
# GOOD: Parallel execution for independent checks
Launch in parallel:
1. pipeline-critic (code-review mode)
2. security-reviewer

# BAD: Sequential when independent
First critic, then security-reviewer
```

Do NOT parallelize dependent steps (executor must finish before critic starts).

## Multi-Perspective Analysis

For ambiguous decisions (not code quality), use `/council` skill — it convenes Architect, Skeptic, Pragmatist, and Critic voices for decision-making under ambiguity. This is separate from the pipeline's code quality review.
