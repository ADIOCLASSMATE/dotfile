---
paths:
  - "**/*.ts"
  - "**/*.tsx"
  - "**/*.js"
  - "**/*.jsx"
---
# TypeScript/JavaScript Testing

> This file extends [common/testing.md](../common/testing.md) with TypeScript/JavaScript specific content.

## Unit Testing Framework: Vitest

Use **Vitest** as the primary test framework. It is fast, compatible with Jest APIs, and has native ESM/TypeScript support.

```bash
npx vitest                  # Run tests
npx vitest --coverage       # Run with coverage
npx vitest --ui             # Interactive UI
```

### Configuration

```typescript
// vitest.config.ts
import { defineConfig } from 'vitest/config'

export default defineConfig({
  test: {
    coverage: {
      provider: 'v8',
      thresholds: {
        lines: 80,
        branches: 80,
        functions: 80,
      },
    },
  },
})
```

## Test Structure (AAA Pattern)

Use the Arrange-Act-Assert pattern with TypeScript:

```typescript
import { describe, test, expect } from 'vitest'

describe('calculateCosineSimilarity', () => {
  test('returns 1 for identical vectors', () => {
    // Arrange
    const vector1 = [1, 0, 0]
    const vector2 = [1, 0, 0]

    // Act
    const similarity = calculateCosineSimilarity(vector1, vector2)

    // Assert
    expect(similarity).toBe(1)
  })

  test('returns 0 for orthogonal vectors', () => {
    const result = calculateCosineSimilarity([1, 0, 0], [0, 1, 0])
    expect(result).toBe(0)
  })

  test('throws on empty vectors', () => {
    expect(() => calculateCosineSimilarity([], [])).toThrow()
  })
})
```

## Test Naming

Use descriptive names that explain the behavior under test:

```typescript
test('returns empty array when no markets match query', () => {})
test('throws error when API key is missing', () => {})
test('falls back to substring search when Redis is unavailable', () => {})
```

## Mocking

Vitest has built-in mocking via `vi`:

```typescript
import { vi, test, expect } from 'vitest'

// Mock a module
vi.mock('./api', () => ({
  fetchUser: vi.fn().mockResolvedValue({ id: 1, name: 'Alice' }),
}))

// Mock a function
const mockFn = vi.fn().mockReturnValue('result')
expect(mockFn).toHaveBeenCalledOnce()
```

## Integration Testing

For API endpoint testing, use Supertest or Vitest with `fetch`:

```typescript
import { test, expect } from 'vitest'

test('GET /api/users returns 200', async () => {
  const response = await fetch('http://localhost:3000/api/users')
  expect(response.status).toBe(200)
  const data = await response.json()
  expect(Array.isArray(data)).toBe(true)
})
```

## E2E Testing

Use **Playwright** for end-to-end testing of critical user flows:

```bash
npx playwright test              # Run all E2E tests
npx playwright test --ui         # Interactive mode
npx playwright test --trace on   # With trace for debugging
```

For more detailed E2E patterns, see `skills/e2e-testing/SKILL.md`.

## Agent Support

- **tdd-guide** - TDD specialist, enforces write-tests-first
- **e2e-runner** - Playwright E2E testing specialist
