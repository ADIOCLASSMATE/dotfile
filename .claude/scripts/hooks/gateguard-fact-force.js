#!/usr/bin/env node
/**
 * PreToolUse Hook: GateGuard — Silent Advisory Guardian
 *
 * All interventions use allow + additionalContext (silent injection).
 * The tool always proceeds; guidance is injected into model context.
 *
 * Triggers:
 *   - Write (new file) → requires Glob + Grep search for duplicates before creating
 *   - Edit/MultiEdit deleting >3 lines → requires Grep for dangling references before deleting
 *   - Edit/MultiEdit replacing >10 lines → requires Read context + Grep for call site impact
 *   - Bash destructive commands → requires Grep for references to deletion targets
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
    '- Identify the specific file/directory targets from the command before running Grep.',
    '- You MUST run Grep to find all files that import or reference the targets being deleted/overwritten. Report the Grep results.',
    '- If any references are found, you MUST fix or remove them BEFORE executing this command.',
    '- If no references exist, state the Grep command you ran and that it returned 0 matches.',
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
    '- You MUST use Grep to search the codebase for references to the symbols/functions/exports being deleted. Report the Grep results.',
    '- If references are found, you MUST update or remove them BEFORE proceeding. Do not leave dangling references.',
    '- You MUST verify this deletion was explicitly requested. If the user did not request it, stop and ask for confirmation. If they did, state what they asked for.',
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
    '- You MUST use Glob to search for files with similar names (e.g., glob pattern matching the file basename or purpose). Report the Glob results.',
    '- You MUST use Grep to search for existing utilities/functions that serve the same purpose. Report the Grep results.',
    '- If a similar file exists, you MUST Read it and explain why editing it is insufficient before creating a new one.',
    '- State the specific purpose of this file and how it serves the current goal.',
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
    '- State the specific purpose of this change and how it moves toward the current goal.',
    '- You MUST Read the surrounding context (lines before and after the edit region) to verify the scope is correct — not replacing more than intended. Report what you found.',
    '- You MUST determine whether the edit removes or changes any exported symbols. If it does, use Grep to find all call sites and confirm they will still work after this change. Report your findings.',
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
