---
name: go-coder
description: Go coding patterns, TDD idioms, error handling, and project conventions for writing production-quality Go code
---

# Go Coder

Production-quality Go code following Google, Uber, Effective Go, and CodeReviewComments style guides.

---

## Error Handling

### Handle Errors Once
Choose ONE response — never log AND return:

```go
// Bad: logs AND returns — causes duplicate noise up the call stack
u, err := getUser(id)
if err != nil {
    log.Printf("Could not get user %q: %v", id, err)
    return err
}

// Good: wrap and return — let caller decide
u, err := getUser(id)
if err != nil {
    return fmt.Errorf("get user %q: %w", id, err)
}
```

### %w vs %v
- `%w`: preserves the error chain for `errors.Is`/`errors.As` — use within a system
- `%v`: hides internal details — use at system boundaries, for logging, or when callers shouldn't inspect

Place `%w` at the **end**: `"context message: %w"`.

### Sentinel Errors

```go
var ErrNotFound = errors.New("not found")

// Check with errors.Is — never string matching
if errors.Is(err, ErrNotFound) { ... }
```

| Caller needs to match? | Message type | Use |
|------------------------|--------------|-----|
| No | static | `errors.New("message")` |
| No | dynamic | `fmt.Errorf("msg: %v", val)` |
| Yes | static | `var ErrFoo = errors.New("...")` |
| Yes | dynamic | custom `error` type |

### Ignoring Errors
If ignoring is appropriate, add a comment explaining why:

```go
n, _ := b.Write(p) // bytes.Buffer.Write never returns a non-nil error
```

### Named Returns Required for Deferred Error Propagation
When a deferred call (typically `Close()`) needs to propagate its error to the caller, named return values are required — a defer can only mutate a named return variable, not a bare `error` return.

```go
// Bad: deferred close error is silently discarded
func writeConfig(path string, data []byte) error {
    f, err := os.Create(path)
    if err != nil { return err }
    defer f.Close() // error lost
    _, err = f.Write(data)
    return err
}

// Good: named return lets defer capture the close error
func writeConfig(path string, data []byte) (err error) {
    f, err := os.Create(path)
    if err != nil { return err }
    defer func() {
        if cerr := f.Close(); cerr != nil && err == nil {
            err = cerr
        }
    }()
    _, err = f.Write(data)
    return
}
```

### errgroup for Related Operations

```go
g, ctx := errgroup.WithContext(ctx)
g.Go(func() error { return task1(ctx) })
g.Go(func() error { return task2(ctx) })
if err := g.Wait(); err != nil {
    return err
}
```

---

## Interfaces

Define interfaces in the package that **uses** them, not the package that implements them. This keeps coupling low and avoids circular imports.

---

## Concurrency

### Never Start a Goroutine Without Knowing How It Will Stop
Goroutines can leak by blocking on channel sends/receives. The GC will **not** terminate a blocked goroutine.

```go
// Bad: no way to stop or wait
go func() {
    for { flush(); time.Sleep(delay) }
}()

// Good: controlled shutdown
stop := make(chan struct{})
done := make(chan struct{})
go func() {
    defer close(done)
    ticker := time.NewTicker(delay)
    defer ticker.Stop()
    for {
        select {
        case <-ticker.C: flush()
        case <-stop: return
        }
    }
}()
close(stop); <-done
```

### No Goroutines in init()
Expose a `Shutdown`/`Stop`/`Close` method instead — gives callers lifecycle control.

### Mutex: Never Embed in Public Structs
Embedding leaks `Lock`/`Unlock` into the public API:

```go
// Bad: Lock() and Unlock() become public methods
type Cache struct {
    sync.Mutex
    data map[string]string
}

// Good: unexported field
type Cache struct {
    mu   sync.Mutex
    data map[string]string
}
```

### Goroutine Leak Detection
Use `go.uber.org/goleak` in tests for packages that spawn goroutines.

**Checklist before spawning a goroutine:**
- How will it exit? Can I signal it to stop? Can I wait for it?
- Who owns the channels it uses?
- Should this be a synchronous function instead?

---

## Context

Never store `context.Context` in a struct field — pass it as the first parameter to each method that needs it.

Context values must use unexported package-private key types to prevent cross-package collisions:

```go
// Bad: any package can read or overwrite this key
ctx = context.WithValue(ctx, "userID", id)

// Good: unexported type, collision-proof
type contextKey int
const userIDKey contextKey = iota
ctx = context.WithValue(ctx, userIDKey, id)
```

---

## Testing

### Check What the Project Uses
Both approaches are valid — follow the existing codebase:
- **stdlib `testing` + `cmp`**: idiomatic, no deps, Google-style projects
- **`testify/assert` + `testify/require`**: de facto standard in most open-source Go projects, highly readable

### Failure Message Format
Always include: what failed, inputs, got, want. Got before want.

```go
// stdlib style
if got := Add(2, 3); got != 5 {
    t.Errorf("Add(2, 3) = %d, want %d", got, 5)
}

// testify style
assert.Equal(t, 5, Add(2, 3), "Add(2, 3)")
```

### Struct Comparison with cmp.Diff

```go
want := &Doc{Type: "blogPost", Authors: []string{"isaac"}}
if diff := cmp.Diff(want, got); diff != "" {
    t.Errorf("AddPost() mismatch (-want +got):\n%s", diff)
}
```

### t.Error vs t.Fatal
- `t.Error` / `assert.Error`: keeps the test running — report all failures in one run
- `t.Fatal` / `require.NoError`: stops the test immediately — use when continuation is meaningless

Never call `t.Fatal` / `t.FailNow` from goroutines — use `t.Error` instead.

### Test Helpers — Always t.Helper()

```go
func mustLoadTestData(t *testing.T, filename string) []byte {
    t.Helper() // failures point to caller, not here
    data, err := os.ReadFile(filename)
    if err != nil {
        t.Fatalf("Setup failed: could not read %s: %v", filename, err)
    }
    return data
}
```

Use `t.Cleanup` for teardown — it runs even when the test fails.

### testing.TB over *testing.T in Helpers
Accept `testing.TB` instead of `*testing.T` in helper functions unless the helper explicitly calls `t.Run()` or `t.Parallel()` (which `testing.TB` lacks). This allows the same helper to work in benchmarks (`*testing.B`) and fuzz tests (`*testing.F`).

```go
// Bad: locks helper to unit tests only
func setupDB(t *testing.T) *sql.DB { ... }

// Good: works in tests, benchmarks, and fuzz
func setupDB(tb testing.TB) *sql.DB {
    tb.Helper()
    ...
}
```

### t.Skip() for Environmental Prerequisites
Use `t.Skip()` when a test requires something the environment can't provide (missing credentials, specific OS, non-root). `t.Fatal()` marks the test *failed*; `t.Skip()` marks it *inapplicable*.

```go
if os.Getuid() != 0 {
    t.Skip("requires root")
}
```

### No WithFailingXxx() Options for Test Error Paths
Don't add options like `WithFailingMailer()` to production constructors for error-path testing — test concerns leak into the production API.

Reach error paths through real failure modes instead:
- `t.Setenv` with a missing required config
- pass invalid input that triggers validation
- inject a mock that returns the error via the standard interface

### Table-Driven Tests
Use when many cases share identical logic (no conditional assertions or branching per case).
When cases need complex setup, conditional mocking, or multiple branches — use separate test functions instead.

```go
tests := []struct {
    name    string
    a, b    string
    want    int
}{
    {"equal", "abc", "abc", 0},
    {"a_gt_b", "b", "a", 1},
}
for _, tt := range tests {
    t.Run(tt.name, func(t *testing.T) {
        got := Compare(tt.a, tt.b)
        assert.Equal(t, tt.want, got)
    })
}
```

### Test Error Semantics — Not Strings

```go
// Bad: brittle
if err.Error() != "invalid input" { ... }

// Good: semantic
if !errors.Is(err, ErrInvalidInput) { ... }
```

### Test Packages
`package foo` — same-package tests, accesses unexported identifiers.
`package foo_test` — black-box tests, avoids circular dependencies.

---

## Defensive Patterns

### Interface Compliance Checks

```go
var _ http.Handler = (*Handler)(nil)
var _ io.Writer = MyWriter{}
```

### Copy Slices and Maps at API Boundaries
Slices and maps contain pointers — copy to prevent unintended mutation:

```go
func (d *Driver) SetTrips(trips []Trip) {
    d.trips = make([]Trip, len(trips))
    copy(d.trips, trips)
}
```

### Do Not Copy Types with Pointer Semantics
Don't copy `T` if its methods are on `*T`. Common pitfall types: `bytes.Buffer`, `sync.Mutex`, `sync.WaitGroup`.

### Avoid defer in Loop Bodies
`defer` executes at function return, not loop iteration — resources accumulate until the function exits:

```go
// Bad: all f.Close() deferred until function returns
for _, path := range paths {
    f, _ := os.Open(path)
    defer f.Close() // resource leak
    process(f)
}

// Good: extract to a function with its own defer scope
for _, path := range paths {
    if err := processFile(path); err != nil { return err }
}
func processFile(path string) error {
    f, err := os.Open(path)
    if err != nil { return err }
    defer f.Close() // safe
    return process(f)
}
```

### text/template: Enable missingkey=error
Go's `text/template` silently renders missing keys as `<no value>` by default. Always set `missingkey=error` on templates that generate config, paths, or anything structural:

```go
tmpl := template.Must(template.New("backend").
    Option("missingkey=error").
    Parse(`key = "{{ .StatePath }}"`))
```

### Always Use Field Tags on Marshaled Structs
Renaming a field without a tag breaks the serialization contract:

```go
type Stock struct {
    Price int    `json:"price"`
    Name  string `json:"name"`
}
```

### Use crypto/rand for Key Generation
Never use `math/rand` — even time-seeded, it has predictable output:

```go
import "crypto/rand"
func Key() string { return rand.Text() }
```

### Library Functions Must Not Panic on Bad Input
Return an error instead. Panics cannot be caught by callers and skip defers.

---

## Packages

### Avoid init()
`init()` makes code harder to test and reason about. It must be deterministic, independent of other `init()` order, and free of I/O, env vars, and global state mutation.

Prefer explicit constructors that return errors.

### Exit Only in main()
`os.Exit` and `log.Fatal` in library functions skip defers and make testing impossible. Use the `run()` pattern:

```go
func main() {
    if err := run(); err != nil { log.Fatal(err) }
}

func run() error {
    // all logic here — testable, defers run
    return nil
}
```

### Blank Imports
`import _ "pkg"` only in `main` packages or test files — makes clear the import is for side effects only.

---

## Functional Options

Use when a constructor or API has 3+ optional parameters, or when the API needs to grow without breaking callers.

```go
type options struct {
    cache  bool
    logger *zap.Logger
}

type Option func(*options)

func WithCache(c bool) Option   { return func(o *options) { o.cache = c } }
func WithLogger(l *zap.Logger) Option { return func(o *options) { o.logger = l } }

func Open(addr string, opts ...Option) (*Connection, error) {
    o := options{cache: true, logger: zap.NewNop()}
    for _, opt := range opts { opt(&o) }
    // ...
}
```

Use the interface approach (not closures) for public APIs that need testability — closure options aren't comparable, so `assert.Equal(WithCache(true), WithCache(true))` fails.

**Checklist:**
- [ ] `options` struct is unexported
- [ ] Defaults set **before** applying options
- [ ] Required parameters are separate from `...Option`

---

## Linting

### Core Principle
Lint consistently across the **entire** codebase. Never silently skip.

### Agent Instruction
After writing or modifying Go code, **always** attempt to run `golangci-lint run ./...`.

- If not found: warn the user and recommend installing it
- If no `.golangci.yml` exists: warn the user and offer to create a starter config

```bash
golangci-lint run ./...
```

### Minimum Recommended Linters

| Linter | Purpose |
|--------|---------|
| `errcheck` | Ensures errors are handled |
| `goimports` | Formats code and manages imports |
| `revive` | Common style mistakes |
| `govet` | Common code mistakes |
| `staticcheck` | Various static analysis |

---

## Commit Checklist

Before proposing any commit:

1. `gofmt -l .` — returns no output
2. `go build ./...` — succeeds
3. `go test -race ./...` — passes
4. `golangci-lint run ./...` — clean
5. No unused imports or variables

**Coverage merging (Go 1.20+):** Use `go tool covdata` to merge binary coverage profiles — do not concatenate text profiles with `cat`. Text merging creates duplicate `<line>` entries in Cobertura XML that CI parsers silently drop.

```bash
go tool covdata merge -i unit_coverage,integration_coverage -o merged_coverage
go tool covdata textfmt -i merged_coverage -o coverage.txt
```

---

## Worktree commits with mise (orchestration gotcha)

When squashing TDD commits from a git worktree using the **main agent's shell** (not the sub-agent that wrote the code), `git commit` must be wrapped with `mise exec --` so pre-commit hooks inherit the correct Go version:

```bash
cd <worktree-path> && mise exec -- git commit -m "..."
```

Without this, hooks that run `task test`, `task mod-tidy`, or `task lint:todo` will fail with `go.mod requires go >= X.Y.Z (running go A.B.C; GOTOOLCHAIN=local)` because the orchestrator's shell PATH uses system Go, not the mise-managed version. The hooks pass cleanly inside the sub-agent (which runs in a mise-activated context) but fail when invoked by the orchestrator.

Also run `mise trust <worktree-path>/.mise.toml` before any task or hook invocation in a new worktree — without this, mise refuses to load tool versions from the worktree's config.

---

## Indent Error Flow (Avoid if-else After Error Check)

Per [Go CodeReviewComments — Indent Error Flow](https://github.com/golang/go/wiki/CodeReviewComments#indent-error-flow): keep the normal code path at minimal indentation. Invert error conditions and return early — never use an `else` block after a branch that returns.

```go
// Bad: else block after a return is unnecessary indentation
if errors.As(err, &apiErr) {
    switch apiErr.ErrorCode() { ... }
} else {
    return fmt.Errorf("call failed: %w", err)
}

// Good: invert, early return, switch at top level
if !errors.As(err, &apiErr) {
    return fmt.Errorf("call failed: %w", err)
}
switch apiErr.ErrorCode() { ... }
```

This also applies to any `if condition { ... } else { return/continue/break }` — the `else` is always redundant when the `if` body terminates.

---

## Always Wrap Errors With Context

Always wrap errors with `fmt.Errorf("operation description: %w", err)`. Never return bare `err` — it removes the call site from the error chain and makes grep-based debugging harder.

```go
// Bad: bare return — loses call site context
return nil, err

// Good: wrap with minimal context
return nil, fmt.Errorf("query user by id: %w", err)
```

This applies even in thin adapters over GORM or other libraries. The one line cost is worth it.

---

## Authoritative Sources

- [Effective Go](https://go.dev/doc/effective_go)
- [Google Go Style Guide](https://google.github.io/styleguide/go/)
- [Uber Go Style Guide](https://github.com/uber-go/guide/blob/master/style.md)
- [Go Wiki CodeReviewComments](https://github.com/golang/go/wiki/CodeReviewComments)
- [Dave Cheney: Never start a goroutine without knowing how it will stop](https://dave.cheney.net/2016/12/22/never-start-a-goroutine-without-knowing-how-it-will-stop)
- [Dave Cheney: Functional options for friendly APIs](https://dave.cheney.net/2014/10/17/functional-options-for-friendly-apis)
