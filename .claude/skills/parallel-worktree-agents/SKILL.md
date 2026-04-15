---
name: parallel-worktree-agents
description: Dispatch parallel Claude Code agents in isolated git worktrees for conflict-free concurrent work. No external tools or MCP servers required. Use when running multiple experiments, parallel feature development, or any task that benefits from isolated concurrent execution.
---

# Parallel Worktree Agents

Dispatch multiple Claude Code sub-agents in isolated git worktrees for conflict-free parallel execution. Uses only built-in Agent tool capabilities — no external dependencies.

## When to Activate

- User says "run in parallel", "multiple experiments", "isolate this", "worktree", or "concurrent agents"
- Running multiple training experiments with different hyperparameters
- Parallel feature development touching overlapping files
- Need independent agents that won't interfere with each other or the main working tree
- Any task where you'd reach for DevFleet or dmux but want zero external dependencies

## Core Mechanism

Use the Agent tool with `isolation: "worktree"`:

```
Agent({
  description: "Experiment A",
  prompt: "...",
  isolation: "worktree"    // creates isolated git worktree
})
```

This creates a separate git worktree under `.claude/worktrees/` with its own branch based on HEAD. The agent works there in complete isolation — it cannot affect the main working tree or other agents.

## Key Parameters

| Parameter | Purpose |
|-----------|---------|
| `isolation: "worktree"` | Create isolated worktree for the agent |
| `run_in_background: true` | Run agent without blocking (for parallel dispatch) |
| `subagent_type` | Choose specialized agent (e.g., `general-purpose`, `code-reviewer`) |
| `model` | Override model (`sonnet`, `opus`, `haiku`) per agent |

## Worktree Lifecycle

1. **Creation**: `isolation: "worktree"` auto-creates worktree + branch
2. **Execution**: Agent works in isolation, can read/write/edit/run commands freely
3. **Completion**: Agent returns result; worktree path and branch name are in the result
4. **Cleanup**: If agent makes no changes, worktree is auto-removed. If changes exist, worktree + branch are preserved for review/merge.

## Workflow Patterns

### Pattern 1: Parallel Experiments

Run multiple training experiments with different configurations:

```
# Launch 3 experiments in parallel
Agent({ description: "Exp: lr=1e-3", prompt: "Modify config.yaml: set learning_rate to 1e-3, then run `python train.py`. Report final metrics.", isolation: "worktree", run_in_background: true })

Agent({ description: "Exp: lr=1e-4", prompt: "Modify config.yaml: set learning_rate to 1e-4, then run `python train.py`. Report final metrics.", isolation: "worktree", run_in_background: true })

Agent({ description: "Exp: lr=1e-5", prompt: "Modify config.yaml: set learning_rate to 1e-5, then run `python train.py`. Report final metrics.", isolation: "worktree", run_in_background: true })

# All three run concurrently. Compare results when they finish.
```

### Pattern 2: Parallel Feature Development

Independent features that might touch overlapping files:

```
Agent({ description: "Auth middleware", prompt: "Implement JWT auth middleware in src/middleware/auth.ts with token validation and refresh logic. Write unit tests.", isolation: "worktree", run_in_background: true })

Agent({ description: "Rate limiter", prompt: "Implement rate limiting middleware in src/middleware/rate-limit.ts with sliding window algorithm. Write unit tests.", isolation: "worktree", run_in_background: true })

Agent({ description: "Request logger", prompt: "Implement request logging middleware in src/middleware/logger.ts with structured JSON output. Write unit tests.", isolation: "worktree", run_in_background: true })

# Each works on its own copy. Merge branches afterward.
```

### Pattern 3: Research + Implement

Research in one agent, implement in another:

```
Agent({ description: "Research approaches", prompt: "Research best practices for implementing a circuit breaker pattern in Python. Compare approaches, write findings to /tmp/circuit-breaker-research.md", isolation: "worktree" })

# After research completes, implement based on findings
Agent({ description: "Implement circuit breaker", prompt: "Read /tmp/circuit-breaker-research.md and implement the recommended circuit breaker pattern in src/resilience/circuit_breaker.py with tests.", isolation: "worktree" })
```

### Pattern 4: Multi-Perspective Code Review

Run different review agents in parallel on the same codebase:

```
Agent({ description: "Security review", subagent_type: "security-reviewer", prompt: "Review src/api/ for security vulnerabilities", isolation: "worktree", run_in_background: true })

Agent({ description: "Performance review", subagent_type: "performance-optimizer", prompt: "Review src/api/ for performance issues", isolation: "worktree", run_in_background: true })

Agent({ description: "Code quality review", subagent_type: "code-reviewer", prompt: "Review src/api/ for code quality and maintainability", isolation: "worktree", run_in_background: true })
```

### Pattern 5: Sequential with Review

Implement first, then review in a new isolated worktree:

```
# Step 1: Implement
Agent({ description: "Implement feature X", prompt: "Implement feature X with TDD approach...", isolation: "worktree" })
# → returns worktree with changes

# Step 2: Review the implementation
Agent({ description: "Review feature X", subagent_type: "code-reviewer", prompt: "Review the implementation of feature X for quality, security, and correctness", isolation: "worktree" })
```

## Merging Results

After agents complete, merge their worktree branches:

```bash
# Check what branches were created
git worktree list

# Review changes before merging
git log main..<branch-name> --oneline
git diff main...<branch-name>

# Merge if satisfied
git merge <branch-name>

# Clean up worktree
git worktree remove <worktree-path>
```

Or use `EnterWorktree` / `ExitWorktree` to inspect worktrees interactively before merging.

## Best Practices

1. **Independent tasks only.** Agents in worktrees cannot see each other's changes. Don't parallelize tasks where one depends on another's output.
2. **Clear boundaries.** Each agent prompt should specify exactly what files to touch and what to produce.
3. **Collect results centrally.** Have agents write results to known paths (e.g., `/tmp/`, a shared output directory) so you can compare after completion.
4. **Model selection.** Use `haiku` for lightweight research/exploration, `sonnet` for implementation, `opus` for complex architecture decisions.
5. **Limit concurrency.** Each agent consumes API tokens and compute. 3-5 parallel agents is a practical upper bound for most tasks.
6. **Avoid merge conflicts.** When agents might touch the same files, give each a distinct scope. If overlap is unavoidable, merge sequentially instead.
7. **Specify expected output.** Tell each agent exactly what to report back (metrics, file list, summary) so results are comparable.

## Comparison with Alternatives

| Approach | External Deps | Isolation | DAG Orchestration | Persistence |
|----------|--------------|-----------|-------------------|-------------|
| **This skill** (Agent + worktree) | None | Git worktree | Manual | Session-only |
| DevFleet | MCP server | Git worktree | Auto | Cross-session |
| dmux | tmux + dmux | Git worktree | Manual | Session-only |

This skill trades DAG auto-orchestration and cross-session persistence for zero setup. For most development tasks, that's the right tradeoff.

## Common Pitfalls

- **Forgetting `run_in_background`**: Without it, agents run sequentially. Use `run_in_background: true` for true parallelism.
- **Vague prompts**: "Fix the code" is too vague. Specify files, expected changes, and output format.
- **Overlapping file scope**: Two agents editing the same file will cause merge conflicts. Scope their work carefully.
- **Not collecting results**: If agents produce output you need, tell them where to write it and what format to use.
