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
       ├── Derive task slug, create .pipeline/<slug>/
       │
       ├── Write implementation order to .pipeline/<slug>/state.md (think before you code)
       │
       ├── Implement code yourself + run build/test/lint
       │
       ├── Write .pipeline/<slug>/implementation-summary.md for Critic
       │
       ├── Spawn critic (Agent tool, pipeline-review mode)
       │
       ├── Read .pipeline/<slug>/critic-feedback.md, write rebuttal + fix ACCEPT issues
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

1. **Read the approved plan** from `.claude/plans/`, copy it verbatim to `.pipeline/<slug>/plan.md`
2. **Write implementation order** to `.pipeline/<slug>/state.md` before coding
3. **Implement code yourself** — run build/test/lint, then write `.pipeline/<slug>/implementation-summary.md`
4. **Spawn critic** (pipeline-review → rebuttal → pipeline-verify), fix issues, loop until PASS (max 3 rounds)
5. **Relay result** to user

For the complete workflow — rebuttal actions (ACCEPT/EXPLAIN/DEFER), file protocol, state.md template, critic brief formats, loop control rules, and lead discipline — see **`skills/pipeline/SKILL.md`**. That file is the single authority on pipeline mechanics.

For standalone code review outside the pipeline, use the `/critic` skill — it handles context gathering and brief formatting before spawning the critic agent. See `skills/critic/SKILL.md`.

## Specialist Agents

Use when pipeline delegates a specific concern:

| Agent | Purpose | When to Use |
|-------|---------|-------------|
| architect | System design | Architectural decisions |
| tdd-guide | Test-driven development | Lead needs TDD guidance |
| security-reviewer | Security analysis | Critic flags security concerns; use PROACTIVELY after writing auth/input code |
| build-error-resolver | Fix build errors | Lead hits a build failure |
| e2e-runner | E2E testing | Critic needs browser-based verification |
| refactor-cleaner | Dead code cleanup | Code maintenance |
| doc-updater | Documentation | Updating docs |
| silent-failure-hunter | Error handling audit | Swallowed errors, missing propagation, bad fallbacks |
| go-build-resolver | Go build/compilation errors | Minimal changes to fix Go build failures |
| rust-build-resolver | Rust build/borrow-check errors | Minimal changes to fix Rust build failures |
| cpp-build-resolver | C++ build/CMake/linker errors | C++ compilation and template errors |
| dart-build-resolver | Dart/Flutter build errors | Dart analysis and pub dependency issues |
| java-build-resolver | Java/Maven/Gradle errors | Spring Boot, Lombok, and Java build failures |
| kotlin-build-resolver | Kotlin/Gradle build errors | Kotlin compiler and detekt issues |
| pytorch-build-resolver | PyTorch/CUDA runtime errors | Tensor shapes, device, gradient errors |
| database-reviewer | PostgreSQL query/schema review | SQL queries, migrations, indexing, performance |
| docs-lookup | Library/framework documentation | Fetch current docs via Context7 MCP |
| a11y-architect | WCAG 2.2 accessibility design | UI component and design system accessibility |
| performance-optimizer | Performance analysis | Profiling, bundle size, rendering bottlenecks |
| opensource-packager | Open-source packaging (stage 3) | CLAUDE.md, README, LICENSE, CI templates |

## Multi-Perspective Analysis

For ambiguous decisions (not code quality), use `/council` — convenes Architect, Skeptic, Pragmatist, and Risk Analyst voices.
