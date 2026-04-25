# Implementation Summary

## User Requirement
Merge `pipeline-critic` (opus, structured review+scoring+rebuttal loop, pipeline-internal only) and `code-reviewer` (sonnet, one-shot review, externally callable) into a single unified `critic` agent with three modes: pipeline-review, pipeline-verify, and standalone. Stricter PASS threshold: no CRITICAL + no HIGH + weighted ≥7.0.

## Plan Reference
`.pipeline/plan.md` — 4 steps: create merged agent, update references, delete old files, verify.

## Changes

| File | What Changed |
|------|-------------|
| `.claude/agents/critic.md` | **Created** — merged agent combining pipeline-critic's 3-mode protocol, 7-dimension scoring, and structured output with code-reviewer's domain checklists (React/Next.js, Node.js/Backend, Performance), confidence-based filtering, AI-Generated Code Review Addendum, and project-specific guidelines. PASS: no CRITICAL + no HIGH + weighted ≥7.0. Standalone uses S-C[X] numbering. |
| `.claude/agents/pipeline-critic.md` | **Deleted** — replaced by critic.md |
| `.claude/agents/code-reviewer.md` | **Deleted** — replaced by critic.md |
| `.claude/CLAUDE.md` | 3 refs: `pipeline-critic` → `critic`, mode names updated to `pipeline-review`/`pipeline-verify` |
| `.claude/agents/loop-operator.md` | 1 ref: `REJECTED by pipeline-critic` → `REJECTED by critic` |
| `.claude/rules/common/agents.md` | 3 direct refs updated, Pipeline Agents table row rewritten for critic (3 modes), brief format headers renamed, standalone mode brief added |
| `.claude/rules/common/code-review.md` | 1 ref: `code-reviewer` → `critic` with updated description |
| `.claude/skills/pipeline/SKILL.md` | 6 refs: `pipeline-critic` → `critic`, mode names updated to `pipeline-review`/`pipeline-verify` |
| `.claude/skills/council/SKILL.md` | 1 ref: `code-reviewer` → `critic` |
| `.claude/skills/prompt-optimizer/SKILL.md` | 4 `pipeline-critic` + 7 `code-reviewer` refs → `critic` |
| `.claude/skills/agent-introspection-debugging/SKILL.md` | 2 refs: `pipeline-critic` → `critic` |
| `.claude/skills/parallel-worktree-agents/SKILL.md` | 3 refs: `code-reviewer` → `critic` |
| `.claude/PLUGIN_SCHEMA_NOTES.md` | 2 refs: `code-reviewer.md` → `critic.md` in examples |

## Design Decisions
1. **Keep 7 dimensions, not 10**: React/Next.js, Node.js/Backend, Performance are sub-checklists within existing dimensions, not separate scored dimensions. Avoids conditional weight redistribution math.
2. **Standalone uses S-C[X] prefix**: Prevents cross-context confusion with pipeline-review's R[N]-C[X]. User specifically requested this.
3. **opus model**: Inherited from pipeline-critic. Code-reviewer was sonnet; the merged agent uses opus for deeper analysis across all modes.
4. **Stricter PASS (no HIGH)**: Old pipeline-critic allowed ≤2 HIGH. Now aligned with code-reviewer's standard.
5. **Plugin files untouched**: All 19 `code-reviewer` references in `.claude/plugins/` are upstream submodules — not modified.

## Known Tradeoffs
- Plugin agents named `code-reviewer` coexist with the project-level `critic`. When a plugin invokes `code-reviewer`, it resolves to the plugin's own definition (plugin agents take precedence for plugin-internal references). No conflict expected.
- Standalone mode does not support the rebuttal/verify loop. Callers needing iterative review should use the pipeline workflow instead.
