# Global rules (pointer to detailed rules)

## Workflow: use the pipeline for non-trivial tasks

When a task involves 3+ files, new features, refactoring, or investigation that benefits from plan-execute-review iteration, use `/pipeline` instead of ad-hoc implementation. The pipeline orchestrates pipeline-lead → pipeline-executor → pipeline-critic in a quality-gated loop.

For simple fixes (1-2 files, obvious change), just do it directly.

See `~/.claude/rules/common/agents.md` for the full pipeline diagram and decision table.

## Python environment management
- See `~/.claude/rules/python/environment.md` for uv workflows.

## Coding style
- See `~/.claude/rules/common/coding-style.md`.
