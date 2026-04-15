#!/usr/bin/env node
/**
 * PreToolUse Hook: GateGuard — Silent Advisory Guardian
 *
 * All interventions use allow + additionalContext (silent injection).
 * The tool always proceeds; guidance is injected into model context.
 *
 * Triggers:
 *   - Write (new file) → duplication & usage check
 *   - Edit/MultiEdit deleting >3 lines → deletion check
 *   - Edit/MultiEdit replacing >10 lines → scope check
 *   - Bash destructive commands → safety check
 *   - Small edits / safe Bash → passthrough (no intervention)
 *
 * Compatible with direct invocation via module.exports.run().
 * Cross-platform (Windows, macOS, Linux).
 */

'use strict';

const path = require('path');

// ── Constants ────────────────────────────────────────────────────

const LARGE_EDIT_THRESHOLD = 10;
const DELETION_LINE_THRESHOLD = 3;

const DESTRUCTIVE_BASH = /\b(rm\s+-rf|rm\s+(?!-i\b)[\w\s.\/~*-]+|git\s+reset\s+--hard|git\s+checkout\s+--|git\s+clean\s+-f|drop\s+table|delete\s+from|truncate|git\s+push\s+--force|dd\s+if=)/i;

// ── Sanitize ───────────────────────────────────────────────────────

function sanitizePath(filePath) {
  return filePath.replace(/[\x00-\x1f\x7f\u200e\u200f\u202a-\u202e\u2066-\u2069]/g, ' ').trim().slice(0, 500);
}

// ── Count lines in a string ────────────────────────────────────────

function countLines(str) {
  if (!str) return 0;
  return str.split('\n').length;
}

// ── Guide messages ─────────────────────────────────────────────────

/**
 * Destructive Bash — safety check.
 */
function destructiveBashMsg(command) {
  return [
    '[Check] Destructive command detected.',
    '',
    '- List every file/directory that will be permanently deleted or overwritten.',
    '- Confirm nothing else depends on or references these targets.',
  ].join('\n');
}

/**
 * Large deletion — removal check.
 */
function deletionAdviceMsg(filePath, lineCount) {
  const safe = sanitizePath(filePath);
  return [
    `[Check] Removing ${lineCount} lines from ${safe}.`,
    '',
    '- Confirm the deleted content is not referenced elsewhere.',
    '- Verify this removal is what the user requested.',
  ].join('\n');
}

/**
 * New file creation — duplication & usage check.
 */
function newFileAdviceMsg(filePath) {
  const safe = sanitizePath(filePath);
  return [
    `[Check] Creating new file: ${safe}`,
    '',
    '- What is the purpose of creating this file? How does it serve the current goal?',
    '- Confirm no existing file already serves this purpose.',
  ].join('\n');
}

/**
 * Large edit (>threshold lines) — scope check.
 */
function largeEditAdviceMsg(filePath, lineCount) {
  const safe = sanitizePath(filePath);
  return [
    `[Check] Replacing ${lineCount} lines in ${safe}.`,
    '',
    '- What is the purpose of this change? How does it move toward the current goal?',
    '- Verify the scope is correct — not replacing more than intended.',
  ].join('\n');
}

// ── Output helper ─────────────────────────────────────────────────

function adviseResult(message) {
  return {
    stdout: JSON.stringify({
      hookSpecificOutput: {
        hookEventName: 'PreToolUse',
        permissionDecision: 'allow',
        additionalContext: message,
      },
    }),
    exitCode: 0,
  };
}

// ── Core logic ─────────────────────────────────────────────────────

function run(rawInput) {
  let data;
  try {
    data = typeof rawInput === 'string' ? JSON.parse(rawInput) : rawInput;
  } catch (_) {
    return rawInput;
  }

  const rawToolName = data.tool_name || '';
  const toolInput = data.tool_input || {};
  const TOOL_MAP = { 'edit': 'Edit', 'write': 'Write', 'multiedit': 'MultiEdit', 'bash': 'Bash' };
  const toolName = TOOL_MAP[rawToolName.toLowerCase()] || rawToolName;

  // ── Write → advise ──────────────────────────────────────────────

  if (toolName === 'Write') {
    const filePath = toolInput.file_path || '';
    if (!filePath) return rawInput;
    return adviseResult(newFileAdviceMsg(filePath));
  }

  // ── Edit / MultiEdit ─────────────────────────────────────────────

  if (toolName === 'Edit' || toolName === 'MultiEdit') {
    let filePath, oldString;
    if (toolName === 'MultiEdit') {
      const edits = toolInput.edits || [];
      const firstEdit = edits.find(e => e.file_path) || {};
      filePath = firstEdit.file_path || 'unknown';
      oldString = firstEdit.old_string || '';
    } else {
      filePath = toolInput.file_path || '';
      oldString = toolInput.old_string || '';
    }
    if (!filePath) return rawInput;

    const oldLines = countLines(oldString);
    const newString = (toolName === 'MultiEdit')
      ? ((toolInput.edits || []).find(e => e.file_path) || {}).new_string || ''
      : toolInput.new_string || '';
    const isDeletion = oldLines > DELETION_LINE_THRESHOLD && newString.trim() === '';
    const isLargeEdit = oldLines > LARGE_EDIT_THRESHOLD;

    if (isDeletion) {
      return adviseResult(deletionAdviceMsg(filePath, oldLines));
    }
    if (isLargeEdit) {
      return adviseResult(largeEditAdviceMsg(filePath, oldLines));
    }
    return rawInput;
  }

  // ── Bash ─────────────────────────────────────────────────────────

  if (toolName === 'Bash') {
    const command = toolInput.command || '';
    if (DESTRUCTIVE_BASH.test(command)) {
      return adviseResult(destructiveBashMsg(command));
    }
    return rawInput;
  }

  return rawInput;
}

module.exports = { run };

// ── stdin entry point ──────────────────────────────────────────────
if (require.main === module) {
  let data = '';
  process.stdin.setEncoding('utf8');
  process.stdin.on('data', chunk => { data += chunk; });
  process.stdin.on('end', () => {
    const result = run(data);
    if (typeof result === 'object' && result !== null) {
      if (result.stderr) {
        process.stderr.write(result.stderr + '\n');
      }
      if (result.stdout) {
        process.stdout.write(result.stdout);
      } else if (result.exitCode === 0 || result.exitCode === undefined) {
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
