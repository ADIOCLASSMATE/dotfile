# Changelog

All notable changes to this project will be documented in this file.

## [Unreleased]

### Added
- `CLAUDE.md` — project context file (final goal, implementation path, known issues)
- `docs/CHANGELOG.md` — this changelog
- PreCompact hook (`pre-compact-context-preserve.js`) — forces model to re-read `CLAUDE.md` and `CHANGELOG.md` before context compaction, summarizing project state and session changes