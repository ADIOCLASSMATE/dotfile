# Global rules (pointer to detailed rules)

## Workflow: Plan Mode → Pipeline (mandatory, no exceptions)

**ABSOLUTE RULE**: If you entered Plan Mode for a task, after the user approves the plan, you MUST execute it through `/pipeline`. No exceptions.

After `/pipeline` is triggered, you become the pipeline-lead AND executor. You implement code yourself, then spawn critic to review, rebuttal its feedback, and loop until PASS. Max 3 rounds.

For the complete pipeline workflow — responsibilities, file protocol, rebuttal actions, loop control — see `skills/pipeline/SKILL.md`. For agent orchestration, see `rules/common/agents.md`.

## Python environment management
- See `~/.claude/rules/python/environment.md` for uv workflows.

## Coding style
- See `~/.claude/rules/common/coding-style.md`.
