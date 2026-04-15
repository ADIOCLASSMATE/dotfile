---
paths:
  - "**/*.py"
  - "**/*.pyi"
  - "**/pyproject.toml"
  - "**/uv.lock"
---
# Python Environment Management

> This file extends [common/coding-style.md](../common/coding-style.md) with Python environment tooling.

## Default Tooling

- Use **uv** for Python env + dependency management (not pip/conda/poetry).
- Each project uses a local venv at `./.venv`.

## Common Commands

- Create venv: `uv init`
- Sync existing environment (from `pyproject.toml` / lock): `uv sync`
- Add a new dependency (installs + updates lock): `uv add <package>`
- Remove a dependency: `uv remove <package>`
- Run commands inside the project env:
  - `uv run python -m <module>`
  - `uv run pytest`
- Inspect installed packages:
  - `uv pip show <package>`
  - `uv pip list`
- Activate environment: `source .venv/bin/activate`

## Avoid

- Do not suggest `pip install ...` or `uv pip install ...` unless explicitly requested.
- Prefer `uv add/remove` for dependency changes (they update lock files properly).
