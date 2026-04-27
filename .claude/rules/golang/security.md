---
paths:
  - "**/*.go"
  - "**/go.mod"
  - "**/go.sum"
---
# Go Security

> This file extends [common/security.md](../common/security.md) with Go-specific content.

## Secret Management

Use environment variables, never hardcode secrets:

```go
// WRONG
const apiKey = "sk-proj-xxxxx"

// CORRECT
apiKey := os.Getenv("API_KEY")
if apiKey == "" {
    log.Fatal("API_KEY not set")
}
```

## SQL Injection Prevention

Always use parameterized queries with placeholders (`$1`, `$2`, etc.):

```go
// WRONG: SQL injection via string concatenation
query := fmt.Sprintf("SELECT * FROM users WHERE email = '%s'", email)

// CORRECT: Parameterized query
row := db.QueryRowContext(ctx,
    "SELECT id, name, email FROM users WHERE email = $1",
    email,
)
```

For dynamic column/table names, validate against an allowlist:

```go
var allowedColumns = map[string]bool{"id": true, "name": true, "email": true}

func buildOrderBy(col string) (string, error) {
    if !allowedColumns[col] {
        return "", fmt.Errorf("invalid column: %s", col)
    }
    return col, nil
}
```

## Dependency Auditing

```bash
go vet ./...                      # Built-in static analysis
govulncheck ./...                 # Vulnerability scanning
go mod verify                     # Verify dependency integrity
```

Install `govulncheck`: `go install golang.org/x/vuln/cmd/govulncheck@latest`

## Input Validation

Validate at boundaries — parse, don't just check:

```go
type CreateUserInput struct {
    Name  string `validate:"required,min=1,max=100"`
    Email string `validate:"required,email,max=255"`
}

func (s *UserService) CreateUser(ctx context.Context, input CreateUserInput) (*User, error) {
    if err := validator.New().Struct(input); err != nil {
        return nil, fmt.Errorf("invalid input: %w", err)
    }
    return s.repo.Create(ctx, &User{Name: input.Name, Email: input.Email})
}
```

## Error Message Discipline

Never expose internal details to callers:

```go
// WRONG: Leaks database details
return fmt.Errorf("postgres connection failed: %w", err)

// CORRECT: Generic message, log the detail internally
slog.Error("database error", "error", err)
return fmt.Errorf("internal error")
```

## References

For detailed Go patterns, see `skills/golang-patterns/SKILL.md`.
