# Changelog

All notable changes to this project will be documented in this file.

## [Unreleased]

### Added
- `CLAUDE.md` — project context file (final goal, implementation path, known issues)
- `docs/CHANGELOG.md` — this changelog
- PreCompact hook (`pre-compact-context-preserve.js`) — forces model to re-read `CLAUDE.md` and `CHANGELOG.md` before context compaction, summarizing project state and session changes

### Changed (2026-04-19)
- Deleted `~/.claude/AGENTS.md` — redundant with `rules/common/agents.md`, contained stale `planner` references, and had no entry point referencing it
- Deleted `~/.claude/skills/learned/` — temporary learning record (`arxiv-latex-reliability.md`), not a proper skill
- Updated `rules/README.md` to include `swift/` directory (commit 3297d2b)