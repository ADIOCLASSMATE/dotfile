---
paths:
  - "**/*.go"
  - "**/go.mod"
---
# Go Hooks

> This file extends [common/hooks.md](../common/hooks.md) with Go-specific content.

## Essential PostToolUse Hooks

### Format on Write

Auto-format Go files after every edit:

```bash
gofmt -w <changed-files>
```

### Compile Check

Verify compilation after changes:

```bash
go build ./...
```

### Vet Check

Run static analysis:

```bash
go vet ./...
```

## Linting with golangci-lint

For comprehensive linting, use golangci-lint:

```bash
golangci-lint run ./...
```

Recommended `.golangci.yml` configuration:

```yaml
linters:
  enable:
    - errcheck
    - gosimple
    - govet
    - ineffassign
    - staticcheck
    - unused
    - revive
    - gofmt
    - goimports
```

## Tool Availability

- `gofmt`: Built-in with Go installation — always available
- `go vet`: Built-in — always available
- `golangci-lint`: Install with `go install github.com/golangci/golangci-lint/cmd/golangci-lint@latest`
