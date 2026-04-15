#!/usr/bin/env node
let data = '';
process.stdin.on('data', chunk => data += chunk);
process.stdin.on('end', () => {
  process.stderr.write('[TEST HOOK] PreToolUse hook fired! Input: ' + data.slice(0, 100) + '\n');
  process.stdout.write(data);
  process.exit(0);
// hook test edit
});
