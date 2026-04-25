# Agent Orchestration

## One Rule: Plan Mode → Pipeline (mandatory)

If Plan Mode was entered and the plan was approved, Pipeline is mandatory. No exceptions.

```text
Plan Mode approved
       │
       ▼
  /pipeline triggered
       │
       ▼
  YOU (main agent) = pipeline-lead + executor
       │
       ├── Read approved plan from .claude/plans/
       │
       ├── Write implementation order to state.md (think before you code)
       │
       ├── Implement code yourself + run build/test/lint
       │
       ├── Write implementation-summary.md for Critic
       │
       ├── Spawn critic (Agent tool, pipeline-review mode)
       │
       ├── Read critic-feedback.md, write rebuttal + fix ACCEPT issues
       │
       ├── Spawn critic (Agent tool, pipeline-verify mode)
       │     │
       │     FAIL → fix issues, append Round N Changes to summary, loop (max 3 rounds)
       │     PASS → done
       │
       └── (if same issue REJECTED 2 rounds in a row) → spawn loop-operator
```

## Why the main agent is the lead AND executor

Subagents cannot spawn further subagents in Claude Code. So pipeline-lead must be the main agent, which has the Agent tool and can spawn critic directly. The main agent also implements code directly — no executor subagent needed, since you have full conversation context and zero information loss.

## Pipeline Agents

| Agent | Who | Tools | Role |
|-------|-----|-------|------|
| pipeline-lead | **You (main agent)** | All | Read plan, implement code, write implementation summary, rebuttal, loop control |
| critic | Subagent (opus) | Read, Grep, Glob, Bash, Agent | Review code + implementation summary, PASS/FAIL verdict, rebuttal evaluation. Three modes: pipeline-review, pipeline-verify, standalone |
| loop-operator | Subagent (sonnet) | Read, Grep, Glob, Bash, Edit | Diagnose stalls, recommend recovery |

## Your Responsibilities as Pipeline-Lead

1. **Read the approved plan** — Load from `.claude/plans/`. Do NOT redo research.
2. **Write implementation order** — To `.pipeline/state.md` before coding (think before you write)
3. **Implement code yourself** — You are the executor. Write code, run build/test/lint.
4. **Write implementation summary** — To `.pipeline/implementation-summary.md` before spawning Critic. Critic cannot read your mind.
5. **Spawn critic (pipeline-review mode)** — Pass implementation summary + plan path + changed files
6. **Write rebuttal** — Read `.pipeline/critic-feedback.md`, respond to each issue (ACCEPT/EXPLAIN/DEFER), fix ACCEPT issues, append Lead Rebuttal section
7. **Spawn critic (pipeline-verify mode)** — Pass critic-feedback.md path + implementation summary
8. **Loop** — If FAIL, fix remaining issues, append Round N Changes to summary, re-spawn critic
9. **Relay result** — Return final output to user

The critic also supports **standalone mode** for direct invocation outside the pipeline (e.g., code review after writing code, security review). Brief format:

```text
Review the following code for quality, security, and correctness.

Mode: standalone
Files to review: [list file paths or describe diff range]
Focus areas: [optional — security, architecture, all]

Use S-C[X] numbering for issues. Output directly to conversation (not to .pipeline/).
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

## Critic Brief Format

### pipeline-review mode brief

```text
Review the implementation against the plan and implementation summary.

Mode: pipeline-review
Round: [N]
Plan file: .pipeline/plan.md
Implementation summary: .pipeline/implementation-summary.md
Critic feedback file: .pipeline/critic-feedback.md
Changed files: [list all files to review]

## Focus areas
[Which aspects to evaluate — functionality, architecture, security, all]

Evaluate and write numbered feedback (R[N]-C1, R[N]-C2, etc.) to critic-feedback.md.
Append a new ## Round [N] section with ### Critic Feedback.
Do NOT modify existing content in the file.
```

### pipeline-verify mode brief

```text
Evaluate the Lead's rebuttal to your previous review.

Mode: pipeline-verify
Round: [N]
Critic feedback file: .pipeline/critic-feedback.md (read it — contains your feedback + Lead rebuttal)
Implementation summary: .pipeline/implementation-summary.md (check for Round [N] Changes at the end)

For each Lead rebuttal item:
- ACCEPT/Fixed: verify the fix by reading the code at the Diff Summary location
- EXPLAIN: judge whether the explanation is valid
- DEFER: verify severity is MEDIUM/LOW (if CRITICAL/HIGH, REJECT)

Append ### Critic Verdict + Round Verdict after ### Lead Rebuttal in the current round.
Do NOT modify existing Critic Feedback or Lead Rebuttal content.
If fix code introduces a new CRITICAL issue, report it. Do NOT report new HIGH/MEDIUM/LOW.
```

## Loop Control

- Maximum 3 rounds (1 round = review → rebuttal → verify)
- Third round still FAIL with CRITICAL → report to user, do NOT auto-pass
- Third round still FAIL with only HIGH/MEDIUM → Lead decides, record in state.md
- If same issue REJECTED by Critic for 2 consecutive rounds and Lead still disagrees → spawn loop-operator

## Specialist Agents

Use when pipeline delegates a specific concern:

| Agent | Purpose | When to Use |
|-------|---------|-------------|
| architect | System design | Architectural decisions |
| tdd-guide | Test-driven development | Lead needs TDD guidance |
| security-reviewer | Security analysis | Critic flags security concerns |
| build-error-resolver | Fix build errors | Lead hits a build failure |
| e2e-runner | E2E testing | Critic needs browser-based verification |
| refactor-cleaner | Dead code cleanup | Code maintenance |
| doc-updater | Documentation | Updating docs |

## Multi-Perspective Analysis

For ambiguous decisions (not code quality), use `/council` — convenes Architect, Skeptic, Pragmatist, and Critic voices.
