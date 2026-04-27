---
paths:
  - "**/*.go"
  - "**/*_test.go"
  - "**/go.mod"
---
# Go Testing

> This file extends [common/testing.md](../common/testing.md) with Go-specific content.

## Test Framework

Use Go's built-in `testing` package. No external framework needed — the standard library is sufficient and idiomatic.

```bash
go test ./...                  # Run all tests
go test -v ./...               # Verbose output
go test -race ./...            # Race detector
go test -coverprofile=coverage.out ./...  # Coverage
go tool cover -html=coverage.out          # HTML coverage report
```

## Table-Driven Tests

The idiomatic Go testing pattern:

```go
func TestAdd(t *testing.T) {
    tests := []struct {
        name     string
        a, b     int
        expected int
    }{
        {"positive numbers", 2, 3, 5},
        {"zero", 0, 0, 0},
        {"negative numbers", -1, 1, 0},
    }

    for _, tt := range tests {
        t.Run(tt.name, func(t *testing.T) {
            got := Add(tt.a, tt.b)
            if got != tt.expected {
                t.Errorf("Add(%d, %d) = %d; want %d", tt.a, tt.b, got, tt.expected)
            }
        })
    }
}
```

## Subtests with t.Run

Use `t.Run` for test organization and parallel execution:

```go
func TestUserService(t *testing.T) {
    t.Run("CreateUser", func(t *testing.T) {
        t.Parallel()
        // ...
    })
    t.Run("DeleteUser", func(t *testing.T) {
        t.Parallel()
        // ...
    })
}
```

## Test Helpers

Call `t.Helper()` in test utility functions for correct line numbers in failure output:

```go
func assertEqual(t *testing.T, got, want any) {
    t.Helper()
    if got != want {
        t.Errorf("got %v, want %v", got, want)
    }
}
```

## Mocking with Interfaces

Go's implicit interfaces make mocking trivial — no framework needed:

```go
type UserRepo interface {
    FindByID(ctx context.Context, id string) (*User, error)
}

type mockUserRepo struct {
    user *User
    err  error
}

func (m *mockUserRepo) FindByID(ctx context.Context, id string) (*User, error) {
    return m.user, m.err
}
```

## Coverage Targets

- Critical business logic: 100%
- Public API: 90%+
- General code: 80%+

```bash
go test -coverprofile=coverage.out ./...
go tool cover -func=coverage.out | grep total
```

## Benchmarking

```go
func BenchmarkAdd(b *testing.B) {
    for b.Loop() {
        Add(2, 3)
    }
}
```

Run with: `go test -bench=. -benchmem`

## References

For detailed Go testing patterns, see `skills/golang-testing/SKILL.md`.
