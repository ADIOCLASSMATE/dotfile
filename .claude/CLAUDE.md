# Global rules (pointer to detailed rules)

## Workflow: Plan Mode → Pipeline (mandatory, no exceptions)

**ABSOLUTE RULE**: If you entered Plan Mode for a task, after the user approves the plan, you MUST execute it through `/pipeline`. No exceptions.

After `/pipeline` is triggered, you become the pipeline-lead AND executor. You implement code yourself, then spawn pipeline-critic to review, rebuttal its feedback, and loop until PASS.

### Pipeline flow (you are the lead + executor)

```
1. Read approved plan from .claude/plans/
2. Write implementation order to state.md (think before you code)
3. Implement code yourself
4. Run build/test/lint yourself
5. Write implementation summary for Critic
6. Spawn pipeline-critic (Agent tool, subagent_type="pipeline-critic", review mode)
7. Write rebuttal in critic-feedback.md
8. Spawn pipeline-critic (Agent tool, subagent_type="pipeline-critic", verify mode)
9. If FAIL → fix issues + loop (max 3 rounds)
10. If same issue REJECTED 2 rounds in a row → spawn loop-operator
11. If PASS → relay final result to user
```

No conditions, no "unless", no judgment calls.

See `~/.claude/rules/common/agents.md` for the full pipeline diagram.

## Python environment management
- See `~/.claude/rules/python/environment.md` for uv workflows.

## Coding style
- See `~/.claude/rules/common/coding-style.md`.
