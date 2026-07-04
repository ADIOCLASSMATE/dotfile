# Hooks

Hooks are event-driven automations that fire before or after Claude Code tool executions.

## How Hooks Work

```
User request → Claude picks a tool → PreToolUse hook runs → Tool executes → PostToolUse hook runs
```

- **PreToolUse** hooks run before the tool executes. They can **block** (exit code 2), **warn** (stderr without blocking), or **advise** (inject additionalContext with `permissionDecision: 'allow'`).
- **PostToolUse** hooks run after the tool completes. They can analyze output but cannot block.
- **Stop** hooks run after each Claude response.

## Active Hooks

Hooks are registered in `~/.claude/settings.json`, not in a standalone `hooks.json`.

### PreToolUse

| Hook | Matcher | Behavior | Description |
|------|---------|----------|-------------|
| **GateGuard** | `Edit\|Write\|MultiEdit` | Advises via `additionalContext` (allow) | Injects `[Check]` prompts for new files, large edits (>10 lines), and deletions (>3 lines) |
| **GateGuard** | `Bash` | Advises via `additionalContext` (allow) | Injects `[Check]` prompts for destructive commands (`rm -rf`, `git reset --hard`, etc.) |
| **Pre-commit quality** | `Bash` | Warns via stderr (allow) | Runs quality checks before `git commit`: detects console.log, debugger, secrets, validates commit message format |

### Stop

| Hook | Matcher | Behavior | Description |
|------|---------|----------|-------------|
| **Desktop notify** | `""` | Async notification | Sends macOS/WSL desktop notification when Claude finishes responding |

## GateGuard Silent Advisory

GateGuard uses `permissionDecision: 'allow'` with `additionalContext` to inject `[Check]` messages into the model's context without blocking the operation. The model is required by rule (`coding-style.md` — Check Response CRITICAL) to address every bullet point before proceeding.

Trigger thresholds:
- **Write** (new file): always triggers
- **Edit/MultiEdit** deletion: old_string > 3 lines, new_string empty
- **Edit/MultiEdit** large: old_string > 10 lines
- **Bash** destructive: matches `rm -rf`, `git reset --hard`, `git push --force`, etc.

## Customizing Hooks

Hooks are configured in `~/.claude/settings.json`:

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Edit|Write|MultiEdit",
        "hooks": [{ "type": "command", "command": "node path/to/hook.js" }]
      }
    ]
  }
}
```

### Disabling a Hook

Remove or comment out the hook entry in `settings.json`.

### Writing Your Own Hook

Hooks are Node.js scripts that receive tool input as JSON on stdin and must output JSON on stdout.

**Basic structure:**

```javascript
// my-hook.js
let data = '';
process.stdin.on('data', chunk => data += chunk);
process.stdin.on('end', () => {
  const input = JSON.parse(data);
  const toolName = input.tool_name;
  const toolInput = input.tool_input;

  // Advise mode: inject context without blocking
  console.log(JSON.stringify({
    hookSpecificOutput: {
      hookEventName: 'PreToolUse',
      permissionDecision: 'allow',
      additionalContext: '[Check] Your advisory message here'
    }
  }));

  // Block mode: exit with code 2
  // process.exit(2);
});
```

**Exit codes:**
- `0` — Success (continue execution)
- `2` — Block the tool call (PreToolUse only)
- Other non-zero — Error (logged but does not block)

**Hook Input Schema:**

```typescript
interface HookInput {
  tool_name: string;
  tool_input: {
    command?: string;       // Bash
    file_path?: string;     // Edit/Write/Read
    old_string?: string;    // Edit
    new_string?: string;    // Edit
    content?: string;       // Write
  };
  tool_output?: {           // PostToolUse only
    output?: string;
  };
}
```

## Related

- [rules/common/hooks.md](../rules/common/hooks.md) — Hook architecture guidelines
- [rules/common/coding-style.md](../rules/common/coding-style.md) — Check Response (CRITICAL) rule
- [scripts/hooks/](../scripts/hooks/) — Hook script implementations
