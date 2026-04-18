# Global rules (pointer to detailed rules)

## Workflow: Plan Mode → Pipeline (mandatory, no exceptions)

**ABSOLUTE RULE**: If you entered Plan Mode for a task, after the user approves the plan, you MUST execute it through `/pipeline`. No exceptions.

After `/pipeline` is triggered, you become the pipeline-lead. You orchestrate the pipeline yourself — you read the approved plan, spawn pipeline-executor and pipeline-critic via the Agent tool, and loop until PASS. Do NOT implement anything yourself.

If pipeline-executor or pipeline-critic fails, report the failure to the user. Do NOT fall back to doing it yourself.

### Pipeline flow (you are the lead)

```
1. Read approved plan from .claude/plans/
2. Spawn pipeline-executor (Agent tool, subagent_type="pipeline-executor")
3. Spawn pipeline-critic (Agent tool, subagent_type="pipeline-critic")
4. If FAIL → feed critic feedback to executor, loop (max 3x)
5. If PASS → relay final result to user
```

No conditions, no "unless", no judgment calls, no fallback to direct execution.

See `~/.claude/rules/common/agents.md` for the full pipeline diagram.

## Python environment management
- See `~/.claude/rules/python/environment.md` for uv workflows.

## Coding style
- See `~/.claude/rules/common/coding-style.md`.
