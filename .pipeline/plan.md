# Plan: Enforce uv-only Python environment rules across skills and rules

## Problem
Agent sometimes uses `python3`, `pip install`, or bare `pytest` instead of `uv add`, `uv run python`, `uv run pytest`. Root causes:

1. **Skills contain `pip` references** — `python-patterns/SKILL.md` has `# pip install isort`, `pip-audit`, `safety check`
2. **Skills contain bare commands** — `python-testing/SKILL.md` has `pytest`, `black .`, `mypy .` without `uv run` prefix
3. **Rules have weak enforcement** — `environment.md` says "Do not suggest" instead of CRITICAL/MUST NOT
4. **Rules paths may miss non-.py contexts** — agent running bash commands in any context should respect uv

## Implementation Phases

### Phase 1: Strengthen `environment.md` rule
- Upgrade language to CRITICAL / MUST NOT
- Add explicit command mapping table (pip → uv, python3 → uv run python, etc.)
- Add rule: all Python execution must go through `uv run`

### Phase 2: Fix `python-patterns/SKILL.md`
- Replace `# pip install isort` with `uv add isort --dev`
- Replace `pip-audit` / `safety check` with `uv run pip-audit` / `uv run safety check`
- Wrap all tooling commands with `uv run`

### Phase 3: Fix `python-testing/SKILL.md`
- Wrap all bare `pytest` commands with `uv run pytest`
- Wrap `black`, `ruff`, `mypy`, `bandit` with `uv run`

### Phase 4: Fix `python-reviewer.md` agent
- Update diagnostic commands to use `uv run` prefix

### Phase 5: Fix `rules/python/testing.md`
- Wrap `pytest --cov` with `uv run`

### Phase 6: Verify consistency
- Grep all Python-related files for remaining `pip install`, bare `python3`, bare `pytest` usage

## Success Criteria
- Zero occurrences of `pip install` (except `uv pip install` with explicit caveat)
- All Python tool commands wrapped with `uv run`
- `environment.md` uses CRITICAL/MUST NOT language
- Command mapping table present in environment.md
