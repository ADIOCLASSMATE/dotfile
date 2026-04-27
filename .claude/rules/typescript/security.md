---
paths:
  - "**/*.ts"
  - "**/*.tsx"
  - "**/*.js"
  - "**/*.jsx"
---
# TypeScript/JavaScript Security

> This file extends [common/security.md](../common/security.md) with TypeScript/JavaScript specific content.

## Secret Management

```typescript
// NEVER: Hardcoded secrets
const apiKey = "sk-proj-xxxxx"

// ALWAYS: Environment variables
const apiKey = process.env.OPENAI_API_KEY

if (!apiKey) {
  throw new Error('OPENAI_API_KEY not configured')
}
```

## Dependency Auditing

Run `npm audit` or `yarn audit` regularly. Add to CI:

```yaml
- run: npm audit --audit-level=high
```

Use `pnpm audit` if using pnpm. Fail the build on critical/high vulnerabilities.

## SQL Injection Prevention

Always use parameterized queries. Never concatenate user input into SQL strings:

```typescript
// WRONG: SQL injection via string concatenation
const query = `SELECT * FROM users WHERE email = '${email}'`

// CORRECT: Parameterized query (e.g., with pg or mysql2)
const { rows } = await db.query('SELECT * FROM users WHERE email = $1', [email])

// CORRECT: ORM with safe query builder (Prisma, Drizzle, Knex)
const user = await prisma.user.findUnique({ where: { email } })
```

## NoSQL Injection Prevention

MongoDB and similar databases are also vulnerable. Never pass raw user input to query operators:

```typescript
// WRONG: User controls the query shape
const user = await collection.findOne({ username: { $eq: req.body.username } })

// CORRECT: Validate and constrain input
const username = z.string().min(1).max(100).parse(req.body.username)
const user = await collection.findOne({ username })
```

## XSS Prevention

In React/Next.js, JSX auto-escapes content. Do NOT use `dangerouslySetInnerHTML` with user content:

```typescript
// WRONG: XSS vulnerability
<div dangerouslySetInnerHTML={{ __html: userComment }} />

// CORRECT: Use JSX auto-escaping or sanitize
<div>{userComment}</div>

// If HTML is absolutely required, sanitize with DOMPurify:
import DOMPurify from 'dompurify'
<div dangerouslySetInnerHTML={{ __html: DOMPurify.sanitize(userComment) }} />
```

## CSRF Protection

- Use SameSite cookies (`SameSite=Lax` or `SameSite=Strict`)
- Implement CSRF tokens for state-changing operations
- Next.js: Server Actions include built-in CSRF protection
- Express: Use `csurf` or `lusca` middleware

## JWT Security

```typescript
// Store secrets in environment variables
const secret = process.env.JWT_SECRET
if (!secret) throw new Error('JWT_SECRET not configured')

// Set reasonable expiration
const token = jwt.sign({ userId: user.id }, secret, { expiresIn: '1h' })

// NEVER store tokens in localStorage in browser contexts
// Prefer httpOnly cookies for web applications
```

## HTTP Security Headers

Use Helmet.js in Express applications:

```typescript
import helmet from 'helmet'
app.use(helmet())
```

In Next.js, configure security headers in `next.config.ts`:
- `Content-Security-Policy`
- `X-Content-Type-Options: nosniff`
- `X-Frame-Options: DENY`
- `Strict-Transport-Security`

## Input Validation

Use Zod for all external input (request bodies, query params, URL params):

```typescript
import { z } from 'zod'

const createUserSchema = z.object({
  email: z.string().email().max(255),
  name: z.string().min(1).max(100),
  role: z.enum(['admin', 'user']),
})

// Never trust parsed result without validation
const input = createUserSchema.parse(req.body)
```

## Agent Support

- Use **security-reviewer** agent for comprehensive security audits
