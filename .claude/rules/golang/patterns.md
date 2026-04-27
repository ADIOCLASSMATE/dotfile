---
paths:
  - "**/*.go"
  - "**/go.mod"
---
# Go Design Patterns

> This file extends [common/patterns.md](../common/patterns.md) with Go-specific content.

## Repository Pattern

```go
type UserRepository interface {
    FindByID(ctx context.Context, id string) (*User, error)
    Create(ctx context.Context, user *User) error
    Update(ctx context.Context, user *User) error
    Delete(ctx context.Context, id string) error
}

type PostgresUserRepo struct {
    db *sql.DB
}

func (r *PostgresUserRepo) FindByID(ctx context.Context, id string) (*User, error) {
    row := r.db.QueryRowContext(ctx, "SELECT id, name, email FROM users WHERE id = $1", id)
    // ...
}
```

## Service Layer Pattern

```go
type UserService struct {
    repo UserRepository
}

func (s *UserService) GetUser(ctx context.Context, id string) (*User, error) {
    return s.repo.FindByID(ctx, id)
}
```

## Functional Options Pattern

For configuring complex structs:

```go
type Server struct {
    host    string
    port    int
    timeout time.Duration
}

type Option func(*Server)

func WithTimeout(d time.Duration) Option {
    return func(s *Server) { s.timeout = d }
}

func NewServer(host string, port int, opts ...Option) *Server {
    s := &Server{host: host, port: port, timeout: 30 * time.Second}
    for _, o := range opts {
        o(s)
    }
    return s
}

// Usage: NewServer("localhost", 8080, WithTimeout(10*time.Second))
```

## API Response Envelope

```go
type Response struct {
    Success bool           `json:"success"`
    Data    any            `json:"data,omitempty"`
    Error   string         `json:"error,omitempty"`
    Meta    *Meta          `json:"meta,omitempty"`
}

type Meta struct {
    Total  int `json:"total"`
    Page   int `json:"page"`
    Limit  int `json:"limit"`
}
```

## Context Propagation

Every I/O function must take `context.Context` as its first parameter:

```go
func (s *UserService) CreateUser(ctx context.Context, input CreateUserInput) (*User, error) {
    // ctx carries deadlines, cancellation, and request-scoped values
    return s.repo.Create(ctx, user)
}
```

## References

For detailed Go patterns, see `skills/golang-patterns/SKILL.md`.
