---
paths:
  - "**/*.py"
  - "**/*.pyi"
  - "**/pyproject.toml"
  - "**/uv.lock"
  - "**/*.sh"
  - "**/*.bash"
  - "**/*.zsh"
  - "**/Makefile"
  - "**/Dockerfile"
---
# Python Environment Management

> This file extends [common/coding-style.md](../common/coding-style.md) with Python environment tooling.

## CRITICAL: uv-only Policy

**MUST use uv** for ALL Python environment and dependency management. This is a hard rule with no exceptions unless the user explicitly requests otherwise.

- Use **uv** — NEVER pip, conda, poetry, or system python3.
- Each project uses a local venv at `./.venv`.
- All Python execution MUST go through `uv run`.

## Command Mapping (MANDATORY)

When you find yourself wanting to run any of these, use the uv equivalent instead:

| Do NOT use | Use instead |
|------------|-------------|
| `pip install <pkg>` | `uv add <pkg>` |
| `pip install --dev <pkg>` | `uv add --dev <pkg>` |
| `pip uninstall <pkg>` | `uv remove <pkg>` |
| `python3 <script>` | `uv run python <script>` |
| `python <script>` | `uv run python <script>` |
| `python -m <module>` | `uv run python -m <module>` |
| `pytest` | `uv run pytest` |
| `black .` | `uv run black .` |
| `ruff check .` | `uv run ruff check .` |
| `mypy .` | `uv run mypy .` |
| `bandit -r .` | `uv run bandit -r .` |
| `pip-audit` | `uv run pip-audit` |
| `safety check` | `uv run safety check` |
| `isort .` | `uv run isort .` |
| `pylint <pkg>` | `uv run pylint <pkg>` |

## Common uv Commands

- Create project: `uv init`
- Sync environment (from `pyproject.toml` / lock): `uv sync`
- Add a dependency (installs + updates lock): `uv add <package>`
- Add a dev dependency: `uv add --dev <package>`
- Remove a dependency: `uv remove <package>`
- Run commands inside the project env:
  - `uv run python -m <module>`
  - `uv run pytest`
- Inspect installed packages:
  - `uv pip show <package>`
  - `uv pip list`
- Activate environment: `source .venv/bin/activate`

## MUST NOT

- **MUST NOT** use `pip install` — use `uv add` instead
- **MUST NOT** use `uv pip install` for adding dependencies — use `uv add` (updates lock files properly)
- **MUST NOT** run bare `python3` or `python` — use `uv run python`
- **MUST NOT** run bare `pytest`, `black`, `ruff`, `mypy` etc. — prefix with `uv run`
- `uv pip install` is acceptable ONLY for inspecting installed packages (e.g., `uv pip show`, `uv pip list`). Never use `uv pip install <pkg>` to add packages — always use `uv add`
