# Security Guidelines

## Mandatory Security Checks

Before ANY commit:
- [ ] No hardcoded secrets (API keys, passwords, tokens)
- [ ] All user inputs validated
- [ ] SQL injection prevention (parameterized queries)
- [ ] XSS prevention (sanitized HTML)
- [ ] CSRF protection enabled
- [ ] Authentication/authorization verified
- [ ] Rate limiting on all endpoints
- [ ] Error messages don't leak sensitive data

## Secret Management

- NEVER hardcode secrets in source code
- ALWAYS use environment variables or a secret manager
- Validate that required secrets are present at startup
- Rotate any secrets that may have been exposed

## Security Response Protocol

If security issue found:
1. STOP immediately
2. Use **security-reviewer** agent
3. Fix CRITICAL issues before continuing
4. Rotate any exposed secrets
5. Review entire codebase for similar issues

## Silent Failure Prevention

Swallowed errors and missing error propagation are common sources of production incidents. When code handles I/O, external services, or user input:

- Use **silent-failure-hunter** agent to audit for: empty catch blocks, swallowed exceptions, dangerous fallbacks (`.catch(() => [])`), missing error propagation, and unlogged failures
- Every try/catch must either: recover meaningfully, log with context, or propagate
- Fallback values must never silently hide that a real failure occurred
