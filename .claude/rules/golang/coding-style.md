---
paths:
  - "**/*.go"
  - "**/go.mod"
  - "**/go.sum"
---
# Go Coding Style

> This file extends [common/coding-style.md](../common/coding-style.md) with Go-specific content.

## Formatting

**Always use `gofmt` or `goimports`.** Go has a canonical format — no debates, no configuration.

```bash
gofmt -w .
goimports -w .  # also manages imports
```

## Naming Conventions

- Packages: lowercase, single word, no underscores (e.g., `package auth`, not `package user_auth`)
- Exported identifiers: `PascalCase` (e.g., `GetUser`, `UserID`)
- Unexported identifiers: `camelCase` (e.g., `parseToken`, `userCache`)
- Acronyms: all uppercase or all lowercase (e.g., `HTTPServer`, `userID`, NOT `HttpServer`)
- Getters: omit `Get` prefix (e.g., `func (u *User) Name() string`, not `GetName()`)
- Interfaces: single-method interfaces end in `-er` (e.g., `Reader`, `Writer`, `Closer`)

## Immutability

Prefer returning new values over mutating in place:

```go
// WRONG: Mutates the original slice
func FilterUsers(users []User, active bool) []User {
    result := users[:0]
    for _, u := range users {
        if u.Active == active {
            result = append(result, u)
        }
    }
    return result
}

// CORRECT: Creates a new slice (safe for concurrent reads)
func FilterUsers(users []User, active bool) []User {
    var result []User
    for _, u := range users {
        if u.Active == active {
            result = append(result, u)
        }
    }
    return result
}

// CORRECT: Builder pattern returns new value
func (c Config) WithHost(host string) Config {
    c.host = host
    return c
}
```

## Error Handling

Never ignore errors. Always handle or propagate:

```go
// WRONG: Ignoring error
result, _ := doSomething()
result, err := doSomething()  // err is unused

// CORRECT: Handle or propagate
result, err := doSomething()
if err != nil {
    return fmt.Errorf("doing something: %w", err)
}

// Use %w to wrap errors (preserves unwrap chain for errors.Is/As)
```

## Input Validation

Validate at boundaries before values enter the system:

```go
func NewUser(name, email string) (*User, error) {
    if strings.TrimSpace(name) == "" {
        return nil, fmt.Errorf("name must not be empty")
    }
    if !strings.Contains(email, "@") {
        return nil, fmt.Errorf("invalid email: %s", email)
    }
    return &User{Name: name, Email: email}, nil
}
```

## File Organization

- One package per directory
- Files organized by domain, not by type (e.g., `auth/` contains `token.go`, `middleware.go`, `handler.go`)
- Main package: `cmd/<service-name>/main.go`
- Internal packages: `internal/<domain>/`

## Code Quality Checklist

Before marking work complete:
- [ ] Code compiles with `go build ./...`
- [ ] `go vet ./...` reports no issues
- [ ] `golangci-lint run` passes
- [ ] No `interface{}` — use generics or concrete types
- [ ] Context is plumbed through (every I/O operation takes `context.Context`)
- [ ] Errors are wrapped with context using `fmt.Errorf("...: %w", err)`

## References

For detailed Go patterns, see `skills/golang-patterns/SKILL.md`.
