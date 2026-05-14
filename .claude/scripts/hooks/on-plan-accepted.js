#!/usr/bin/env node
/**
 * PostToolUse Hook: Pipeline Enforcer
 *
 * Detects ExitPlanMode (plan accepted) and injects a short additionalContext
 * reminder to invoke /pipeline. Never blocks — only injects guidance.
 *
 * Degradation: if this hook fails (crash, timeout, missing node), Claude Code
 * logs the error and continues. The text rule in CLAUDE.md is the fallback.
 *
 * Compatible with direct invocation via module.exports.run().
 */

'use strict';

// ── Constants ──────────────────────────────────────────────────────────

const PIPELINE_REMINDER = [
  '[Pipeline] Plan approved via ExitPlanMode.',
  'Per CLAUDE.md: invoke /pipeline now. Do not implement directly.',
].join(' ');

// ── Output helper ─────────────────────────────────────────────────────

function remindResult() {
  return {
    stdout: JSON.stringify({
      hookSpecificOutput: {
        hookEventName: 'PostToolUse',
        additionalContext: PIPELINE_REMINDER,
      },
    }),
    exitCode: 0,
  };
}

// ── Core logic ─────────────────────────────────────────────────────────

function run(rawInput) {
  let data;
  try {
    data = typeof rawInput === 'string' ? JSON.parse(rawInput) : rawInput;
  } catch (_) {
    return rawInput;
  }

  const toolName = data.tool_name || '';

  if (toolName === 'ExitPlanMode') {
    return remindResult();
  }

  return rawInput;
}

module.exports = { run };

// ── stdin entry point ──────────────────────────────────────────────────
if (require.main === module) {
  let data = '';
  process.stdin.setEncoding('utf8');
  process.stdin.on('data', chunk => { data += chunk; });
  process.stdin.on('end', () => {
    const result = run(data);
    if (typeof result === 'object' && result !== null) {
      if (result.stdout) {
        process.stdout.write(result.stdout);
      } else {
        process.stdout.write(data);
      }
      process.exit(result.exitCode || 0);
    } else if (typeof result === 'string') {
      process.stdout.write(result);
      process.exit(0);
    } else {
      process.stdout.write(data);
      process.exit(0);
    }
  });
}
