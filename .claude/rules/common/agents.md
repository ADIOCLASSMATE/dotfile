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
  YOU (main agent) become pipeline-lead
       │
       ├── Read approved plan from .claude/plans/
       │
       ├── Decide: parallel or sequential execution
       │
       ├── Spawn pipeline-executor(s) (Agent tool)
       │
       ├── Spawn pipeline-critic (Agent tool, after ALL executors complete)
       │     │
       │     FAIL → feed feedback to executor(s), loop (max 3x)
       │     PASS → done
       │
       └── (if stalled 2 iterations) → spawn loop-operator
```

## Why the main agent is the lead

Subagents cannot spawn further subagents in Claude Code. So pipeline-lead must be the main agent, which has the Agent tool and can spawn executor and critic directly.

## Pipeline Agents

| Agent | Who | Tools | Role |
|-------|-----|-------|------|
| pipeline-lead | **You (main agent)** | All | Read plan, decide strategy, spawn executor/critic, loop control |
| pipeline-executor | Subagent (sonnet) | Read, Write, Edit, Bash, Grep, Glob | Implement, run verification, report results |
| pipeline-critic | Subagent (opus) | Read, Grep, Glob, Bash, Agent | Review against plan, PASS/FAIL verdict |
| loop-operator | Subagent (sonnet) | Read, Grep, Glob, Bash, Edit | Diagnose stalls, recommend recovery |

## Your Responsibilities as Pipeline-Lead

1. **Read the approved plan** — Load from `.claude/plans/`. Do NOT redo research.
2. **Decide execution strategy** — Parallel or sequential (see rules below)
3. **Write executor briefs** — Must be detailed and self-contained (see rules below)
4. **Spawn executor(s)** — Do NOT implement yourself. Always delegate.
5. **Spawn critic** — Do NOT evaluate yourself. Always delegate.
6. **Loop** — If FAIL, synthesize critic feedback into concrete improvements
7. **Relay result** — Return final output to user

## Pipeline-Lead Discipline

Even though you have all tools (including Write, Edit, Bash), when acting as pipeline-lead you MUST NOT:
- Write or edit source code — that is the executor's job
- Run build/test commands — that is the executor's job
- Evaluate quality yourself — that is the critic's job
- Implement features — that is the executor's job

You MAY use Write to create pipeline files (plan.md, state.md) if needed.

## Execution Strategy: Parallel vs Sequential

### When to use PARALLEL execution

Phases can run in parallel ONLY if ALL of these conditions are met:

1. **File isolation** — No two executors touch the same file
2. **No functional dependency** — Phase B does not depend on Phase A's output
3. **No shared mutable state** — No database migrations, no shared config files

### When to use SEQUENTIAL execution

- Phases have file overlap
- Later phases depend on earlier phases' output
- Shared mutable state exists (migrations, config, etc.)
- You are unsure → default to sequential

### Decision rule

**If in doubt, go sequential.** A slow correct pipeline is better than a fast broken one.

## Executor Brief Rules (CRITICAL)

Subagents have NO access to your conversation history. The prompt is their ONLY context. Therefore:

### Rule 1: Briefs must be self-contained

Every executor brief must include ALL information needed to complete the task. The executor cannot ask you questions mid-execution.

Bad: "Implement the user auth feature as discussed"
Good: "Implement JWT authentication in /src/auth/jwt.ts with the following endpoints: POST /login (accepts email+password, returns JWT), POST /refresh (accepts refresh token, returns new JWT). Use bcrypt for password hashing. Follow the existing pattern in /src/auth/oauth.ts."

### Rule 2: Specify exact file paths

Every file the executor should create or modify must be listed explicitly.

Bad: "Add a new component for the user profile"
Good: "Create /src/components/UserProfile.tsx and /src/components/UserProfile.test.tsx"

### Rule 3: Specify file boundaries for parallel execution

When spawning parallel executors, each brief must explicitly list:
- **Files to create/modify** — exhaustive list
- **Files to READ but NOT modify** — reference files
- **Files to NOT touch** — owned by another executor

```
Executor A brief:
  CREATE: /src/features/auth/login.ts, /src/features/auth/login.test.ts
  READ ONLY: /src/features/auth/types.ts, /src/config/routes.ts
  DO NOT TOUCH: /src/features/auth/register.ts (owned by Executor B)

Executor B brief:
  CREATE: /src/features/auth/register.ts, /src/features/auth/register.test.ts
  READ ONLY: /src/features/auth/types.ts, /src/config/routes.ts
  DO NOT TOUCH: /src/features/auth/login.ts (owned by Executor A)
```

### Rule 4: Include relevant code context

Since executors can't see your conversation, include key code snippets they need to understand:

- Function signatures they need to implement against
- Type definitions they need to conform to
- API contracts they need to follow
- Existing patterns they should replicate

### Rule 5: Specify verification commands

Every brief must include how to verify the work:

```
Verification:
- Run: npm run build
- Run: npm test -- --grep "UserProfile"
- Check: the component renders without errors at /profile
```

## Executor Brief Format

```text
[Task description — 2-3 sentences of what to build and why]

## Files
- CREATE: [list of files to create]
- MODIFY: [list of files to modify, with what changes]
- READ ONLY: [list of reference files]
- DO NOT TOUCH: [list of files owned by other executors, if parallel]

## Requirements
[Detailed, numbered requirements — be specific about behavior, types, patterns]

## Reference Context
[Key code snippets, type definitions, patterns to follow — paste them in]

## Constraints
[Things the executor must NOT do]

## Verification
[Commands to run to verify the implementation]

## Report
After implementation, report:
1. What was built (files created/modified)
2. What changed since last iteration
3. Known issues or deviations from plan
4. Verification command results
```

## Critic Brief Format

```text
Review the implementation against the plan.

Plan file: .claude/pipeline/plan.md (read it for success criteria)

## What was implemented
[Summary from executor report]

## Files to review
[List all files created/modified]

## Focus areas
[Which aspects to evaluate — functionality, quality, security, all]

## Iteration
[N]

Evaluate and return:
1. Verdict: PASS or FAIL
2. Score per criterion (1-10)
3. Critical issues (must fix before PASS)
4. Major issues (should fix)
5. Minor issues (nice to fix)
6. Specific suggestions for next iteration
```

## Loop Control

- Maximum 3 executor→critic cycles
- After 3rd cycle, relay results to user even if not all PASS
- If same critical issues across 2 consecutive iterations → spawn loop-operator (subagent_type="loop-operator")

## Specialist Agents

Use when pipeline delegates a specific concern:

| Agent | Purpose | When to Use |
|-------|---------|-------------|
| architect | System design | Architectural decisions |
| tdd-guide | Test-driven development | Executor needs TDD guidance |
| security-reviewer | Security analysis | Critic flags security concerns |
| build-error-resolver | Fix build errors | Executor hits a build failure |
| e2e-runner | E2E testing | Critic needs browser-based verification |
| refactor-cleaner | Dead code cleanup | Code maintenance |
| doc-updater | Documentation | Updating docs |

## Parallel Execution

Spawn independent checks in parallel. Do NOT parallelize dependent steps (executor must finish before critic starts).

## Multi-Perspective Analysis

For ambiguous decisions (not code quality), use `/council` — convenes Architect, Skeptic, Pragmatist, and Critic voices.
