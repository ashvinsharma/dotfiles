---
name: go-reviewer
description: Go code review checklist covering correctness, idiomatic patterns, concurrency safety, error handling, and performance
---

# Go Reviewer

Review Go code for correctness, idiomatic style, safety, and maintainability.

---

## Review Severity Levels

- **REJECT**: Correctness, safety, or security issue. Must be fixed before merge.
- **COMMENT**: Style, clarity, or maintainability issue. Should be fixed; blocking at reviewer discretion.
- **SUGGEST**: Optional improvement. Nice to have, non-blocking.
- **ESCALATE**: Complexity or risk beyond this review — needs architect involvement.

---

## Review Scope

Review: (1) changed lines, (2) code directly referenced or affected by the change, (3) shared state modified by the change.

Pre-existing issues in **unchanged** code: **SUGGEST only**, marked explicitly as pre-existing. Never REJECT code the author didn't touch — they didn't introduce the problem.

---

## How to Communicate Feedback

Every **REJECT** and **COMMENT** must include:
1. **What** is wrong — be specific, quote the code
2. **Why** it matters — correctness risk, maintenance burden, production impact
3. **How to fix it** — show the corrected form or a concrete next step, and cite the authoritative source

**SUGGEST** comments may be briefer. Don't editorialize — state the issue, the reason, the fix.

---

## When an Author Disputes a REJECT

1. **They provide new technical information** — re-evaluate; revise or withdraw if the argument is sound
2. **They provide only preference or opinion** — hold the REJECT and cite the authoritative source
3. **Genuinely ambiguous** — ESCALATE to architect; don't deadlock the PR

---

## When to Approve

Approve when all three conditions are met:
- Zero open REJECTs
- Every COMMENT is either fixed or the author has provided a technical reason to defer
- No new REJECTs introduced in the latest diff

---

## Before Reviewing — Run These First

```bash
gofmt -l .           # must return no output
go build ./...       # must succeed
go test -race ./...  # must pass with race detector
golangci-lint run ./... # must be clean
```

If `golangci-lint` is not installed, note it as a **COMMENT** and recommend setup.

---

## Error Handling

**REJECT** if any error is silently discarded without an inline comment justifying why:
```go
// Bad: no justification
_ = os.Remove(tmpFile)

// Good: justified
_ = os.Remove(tmpFile) // best-effort cleanup; error is irrelevant to caller
```

**REJECT** if bare `return err` is used without an inline justification comment. Carve-outs that satisfy the rule (but still require a comment):
- Propagating a well-known sentinel (`io.EOF`, `context.Canceled`, `context.DeadlineExceeded`) that must stay unwrapped for `errors.Is()` callers
- Thin adapter/middleware layers where re-wrapping would double-annotate
- Top of the call stack where the caller has full context already

```go
// Bad: no context, no comment
return err

// Good: wrapped
return fmt.Errorf("load config: %w", err)

// Good: justified bare return
return err // propagating io.EOF sentinel — caller uses errors.Is
```

**REJECT** if errors are compared by string:
```go
// Bad
if err.Error() == "not found" { ... }

// Good
if errors.Is(err, ErrNotFound) { ... }
```

**REJECT** if a concrete error type is returned from an exported function — a concrete `nil` pointer becomes a non-nil interface value, and callers can't use the `error` interface reliably:
```go
// Bad: if the function returns (*ConfigError)(nil), the caller gets a non-nil error interface
func Load() *ConfigError { ... }

// Good
func Load() error { ... }
```

**COMMENT** if the author logs AND returns an error — causes duplicate noise up the call stack. Do one or the other.

**COMMENT** if `%v` is used in `fmt.Errorf` when the wrapped error needs to be inspectable by callers via `errors.Is`/`errors.As`. Note: `%v` intentionally severs the chain — only flag when the caller demonstrably needs to unwrap.

---

## Concurrency

**REJECT** if a goroutine is launched without a clear termination strategy:
```go
// Bad: leaks forever
go func() {
    for { doWork() }
}()
```
Ask: how does this exit? Can it be signalled? Can the caller wait for it?

A goroutine with a **clear termination strategy** looks like this:
```go
// Good: context cancellation with select — goroutine exits cleanly
func (w *Worker) Run(ctx context.Context) error {
    var wg sync.WaitGroup
    wg.Add(1)
    go func() {
        defer wg.Done()
        for {
            select {
            case <-ctx.Done():
                return
            case item := <-w.queue:
                process(item)
            }
        }
    }()
    wg.Wait()
    return ctx.Err()
}
```
Done channels and `sync.WaitGroup` are also valid termination mechanisms. The pattern doesn't matter — what matters is that the goroutine can observe a stop signal and the caller can wait for it to finish.

**REJECT** if shared state is accessed without synchronization — confirm with `go test -race ./...`.

**REJECT** if a mutex is embedded in an exported struct — leaks `Lock`/`Unlock` into the public API:
```go
// Bad: exported type — Lock() becomes public
type Cache struct {
    sync.Mutex
    data map[string]string
}

// Good
type Cache struct {
    mu   sync.Mutex
    data map[string]string
}
```
**COMMENT** (not REJECT) for unexported structs with embedded mutex — all call sites are within the package.

**REJECT** if goroutines are spawned in `init()` — no lifecycle control.

**ESCALATE** if the concurrency model involves multiple goroutines sharing complex state, non-obvious ordering guarantees, or lock hierarchies.

---

## Test Quality

**REJECT** if a function has documented error returns and zero tests exercise any of them, or if known edge cases (nil input, empty, zero value) are entirely untested.

**REJECT** if a test helper doesn't call `t.Helper()` — failures point to the wrong line:
```go
// Bad
func mustEqual(t *testing.T, got, want int) {
    if got != want { t.Fatalf(...) }
}

// Good
func mustEqual(t *testing.T, got, want int) {
    t.Helper()
    if got != want { t.Fatalf(...) }
}
```

**REJECT** if `t.Fatal`/`t.FailNow` is called from a goroutine — `runtime.Goexit()` exits the *spawned* goroutine silently while the test goroutine continues and may report success, hiding the failure. Use `t.Error` + `return` instead, or channel the failure back to the test goroutine.

**REJECT** if tests are brittle: time-dependent (`time.Now()` without injection), order-dependent, or reliant on global state.

**REJECT** if error identity is tested by string comparison when a sentinel exists:
```go
// Bad: brittle
assert.EqualError(t, err, "not found")

// Good: semantic
assert.ErrorIs(t, err, ErrNotFound)
```
Note: `assert.EqualError` is acceptable for errors that have no sentinel and where the message is the only contract.

**REJECT** if a test structurally cannot fail — for example, asserting a condition that is always true given the function's implementation, or testing that `errors.New("a") != errors.New("b")`. Evergreen tests inflate coverage metrics, add noise, and drift silently.

**REJECT** if a sort comparator uses integer subtraction (`return int(a - b)`) — overflows on 32-bit platforms and with values larger than `math.MaxInt32/2`. Use `cmp.Compare(a, b)` (Go 1.21+) or explicit `<`/`>` branches.

```go
// Bad: overflows for large int64 values
sort.Slice(items, func(i, j int) bool {
    return int(items[i].Timestamp - items[j].Timestamp) < 0
})

// Good
sort.Slice(items, func(i, j int) bool {
    return cmp.Compare(items[i].Timestamp, items[j].Timestamp) < 0
})
```

**COMMENT** if a test helper accepts `*testing.T` but has no need for `t.Run()` or `t.Parallel()` — it should accept `testing.TB` to work in benchmarks and fuzz tests too.

**COMMENT** if `t.Fatal()` is called to gate a test on an environmental prerequisite (missing credentials, specific OS, non-root). Use `t.Skip()` — `t.Fatal` marks the test failed; `t.Skip` marks it inapplicable.

**COMMENT** if a production constructor exposes a `WithFailingXxx()` option that exists solely to trigger error paths in tests. Reach error paths through real failure modes (mock returning error via its interface, invalid input, `t.Setenv` with missing config).

**COMMENT** if table-driven tests would clearly reduce duplication but aren't used. Don't force it when cases have meaningfully different setup or branching.

**COMMENT** if test names don't describe the scenario. Either `TestFunctionName_Scenario` or descriptive `t.Run("when input is empty", ...)` strings are fine — be consistent with the codebase.

**SUGGEST** `go.uber.org/goleak` for packages that spawn goroutines, to catch leaks in tests.

---

## Naming

**REJECT** stuttering names — the package name is already in scope:
```go
// Bad: user.UserService, http.HTTPClient
// Good: user.Service, http.Client
```
Note: package-eponymous types (`context.Context`, `io.Reader`) are idiomatic, not stuttering.

**REJECT** `Get` prefix on simple accessors in hand-written code:
```go
// Bad: obj.GetName()
// Good: obj.Name()
```
Exempt: protobuf/gRPC generated files, compound verbs where `Get` is load-bearing (`GetOrCreate`, `GetWithDefault`).

**COMMENT** if naming does not follow Go conventions per Effective Go and Go Wiki CodeReviewComments. Cite the principle; use specific violations as examples rather than an exhaustive list. Common violations: inconsistent initialism casing (`HttpClient` → `HTTPClient`, `userId` → `userID`), receiver names that are too long or inconsistent across methods, package names like `util`, `common`, `helper`, `base`.

---

## Interfaces

**REJECT** if an *exported* interface is defined in the same package as its sole concrete implementation with no other consumers or implementations. Go interfaces belong at the point of use.

Exception: shared/utility packages where the interface *is* the contract the package exists to define (e.g. `io.Reader`, `http.Handler`). The test: does this package exist *to define* the abstraction, or does it exist *to implement* something?

Exempt: unexported interfaces used solely for internal testability or package-local abstraction — those never escape the package boundary.

**COMMENT** if an interface has many methods where a smaller one would suffice. Single-method interfaces are idiomatic and compose well.

**COMMENT** if a type assertion is done without the comma-ok idiom — a failed assertion panics:
```go
// Bad: panics if wrong type
f := w.(*os.File)

// Good
f, ok := w.(*os.File)
if !ok { ... }
```

**SUGGEST** a compile-time interface check when there's no static conversion that would catch a missing method:
```go
var _ http.Handler = (*MyHandler)(nil)
```

---

## Context

**REJECT** if `context.Context` is stored in a struct field. Pass context as the first parameter to each method that needs it:
```go
// Bad
type Worker struct{ ctx context.Context }

// Good
func (w *Worker) Run(ctx context.Context) error { ... }
```

**REJECT** if context is not the first parameter when accepted by a function.

**COMMENT** if application data (user ID, config, request data) is passed via context values when it could be passed explicitly or held in a struct. Context values are for request-scoped cross-cutting concerns: trace IDs, auth tokens, deadlines.

**REJECT** if `context.WithValue` is called with a key of a built-in or exported type — keys must be unexported package-private types to prevent cross-package key collisions:
```go
// Bad: any package can read or overwrite this key
ctx = context.WithValue(ctx, "userID", id)
ctx = context.WithValue(ctx, 1, id)

// Good: unexported type, collision-proof
type contextKey int
const userIDKey contextKey = iota
ctx = context.WithValue(ctx, userIDKey, id)
```

---

## Defensive Patterns

**REJECT** if a slice or map received from an external caller is stored directly at an exported API boundary where the caller could plausibly mutate it post-call:
```go
// Bad: caller mutates d.trips after the call
func (d *Driver) SetTrips(trips []Trip) { d.trips = trips }

// Good
func (d *Driver) SetTrips(trips []Trip) {
    d.trips = make([]Trip, len(trips))
    copy(d.trips, trips)
}
```

**COMMENT** inside `internal/` packages — either add a defensive copy, or add a doc comment documenting ownership transfer and confirm no caller mutates post-call.

**REJECT** if a type with pointer semantics is copied (`sync.Mutex`, `bytes.Buffer`, `sync.WaitGroup`) — the copy shares internal state with the original.

**REJECT** if `defer` is used inside a loop body to release a per-iteration resource (file close, mutex unlock) — defers execute at function return, not loop iteration, causing resource exhaustion:
```go
// Bad: f.Close() deferred until function returns, not each iteration
for _, path := range paths {
    f, err := os.Open(path)
    if err != nil { return err }
    defer f.Close() // leaks all handles until function exits
    process(f)
}

// Good: explicit close per iteration
for _, path := range paths {
    if err := processFile(path); err != nil {
        return err
    }
}

func processFile(path string) error {
    f, err := os.Open(path)
    if err != nil { return err }
    defer f.Close() // safe: deferred to end of this function
    return process(f)
}
```

**COMMENT** if `time.Time` or `time.Duration` are represented as raw `int` — units are ambiguous and error-prone.

**COMMENT** if mutable globals are used where dependency injection would make the code testable.

**COMMENT** if marshaled structs (JSON, YAML, etc.) are missing explicit field tags — renaming fields later becomes a breaking serialization change.

---

## Documentation

**COMMENT** if exported types, functions, or methods lack doc comments.

**COMMENT** if a doc comment restates the signature without adding information:
```go
// Bad: "Sets the timeout to d" — the signature already says that
// Good: document what happens when d is zero, or what the default is
```

**COMMENT** if a function acquires a resource (opens file, starts ticker, allocates connection) without documenting the cleanup requirement.

**SUGGEST** a runnable example (`func Example...`) for non-obvious public APIs.

---

## Performance

**REJECT** if an O(n²) algorithm is applied to input derived from an external or user-controlled source with no enforced size cap — this is a production incident, not a style issue:
```go
// Bad on unbounded external input
for i := range items {
    for j := range items { ... } // O(n²)
}

// Good
seen := make(map[string]bool, len(items))
for _, item := range items { ... } // O(n)
```
**COMMENT** if input is internal or bounded by construction.

**REJECT** if goroutines are created unboundedly in a loop over external/user-controlled input with no backpressure — use a worker pool or semaphore.
**COMMENT** if the loop is over a known-small internal collection.

**COMMENT** if containers (`map`, `slice`) are initialized without capacity when the size is known.

**COMMENT** if string concatenation in a loop uses `+` — use `strings.Builder`.

**SUGGEST** `strconv` over `fmt.Sprint` for primitive-to-string conversion in hot paths.

**ESCALATE** if performance analysis requires profiling, benchmarking, or pprof interpretation.

---

## Security

**REJECT** if user input is used in SQL queries without parameterization, in shell commands without argument-list form, or in file paths without `filepath.Clean` + allowlist validation:
```go
// Bad: SQL injection
db.Query("SELECT * FROM users WHERE id = " + userID)

// Good: parameterized
db.Query("SELECT * FROM users WHERE id = ?", userID)

// Bad: shell injection
exec.Command("sh", "-c", "ls " + userInput)

// Good: argument list, no shell interpolation
exec.Command("ls", userInput)
```

**REJECT** if secrets, tokens, or credentials appear in code, test fixtures, or log statements.

**REJECT** if `math/rand` is used to generate security-sensitive values — use `crypto/rand`.

**ESCALATE** for any authentication, authorization, encryption, or PII handling.

---

## Package and Project Structure

**REJECT** if `os.Exit` or `log.Fatal` is called outside of `main()` or `TestMain()` — skips defers, breaks testability, cannot be caught by callers. `TestMain` calling `os.Exit(m.Run())` is the required pattern.

**COMMENT** if `init()` is used for anything beyond reading env vars (12-factor pattern). All other `init()` use — codec registration, lookup table setup, global state mutation, I/O of any kind — is a code smell. Prefer explicit initialization via constructors that return errors. See go-coder guidance on `init()`.

**REJECT** if a library (non-`main`) function panics on input that a caller could plausibly pass — return an error instead. Library code must never panic on bad input:
```go
// Bad: caller has no way to prevent or recover from this
func Parse(data []byte) *Config {
    if data == nil { panic("nil data") }
    ...
}

// Good
func Parse(data []byte) (*Config, error) {
    if data == nil { return nil, errors.New("data must not be nil") }
    ...
}
```

**COMMENT** if `panic` is used as a programmer-invariant guard (impossible state, violated precondition that indicates a bug in the caller's code) — this is acceptable but must have a clear justification comment explaining the invariant.

**COMMENT** if blank imports (`import _ "pkg"`) appear outside of `main` or test files.

**COMMENT** if dot imports (`import . "pkg"`) are used outside of circular test dependency workarounds.

---

## Generics

**COMMENT** if a type parameter is used where an `any` / `interface{}` argument would be functionally identical and no type constraint is actually enforced:
```go
// Bad: the type parameter adds nothing — any interface{} arg would work
func Print[T any](v T) { fmt.Println(v) }

// Good: no type parameter needed
func Print(v any) { fmt.Println(v) }
```

**COMMENT** if `any` is used as a type constraint where a more meaningful interface would make the API clearer and safer:
```go
// Bad: any accepts everything, including non-comparable types
func Contains[T any](slice []T, item T) bool { ... }

// Good: comparable constraint enforces == is valid
func Contains[T comparable](slice []T, item T) bool { ... }
```

**COMMENT** if an exported generic API adds type parameters in a way that increases complexity for callers without a corresponding correctness benefit — prefer concrete types or interfaces when they suffice.

---

## Nil Receiver Patterns

**COMMENT** if a pointer receiver method does not handle a nil receiver when nil is a plausible call-site value — this is a common source of panics:
```go
// Bad: panics on nil
func (n *Node) IsLeaf() bool { return len(n.Children) == 0 }

// Good: nil-safe
func (n *Node) IsLeaf() bool {
    if n == nil { return true }
    return len(n.Children) == 0
}
```

**REJECT** if a nil receiver dereference is reachable without a nil check.

---

## Authoritative Sources to Cite in Reviews

- [Effective Go](https://go.dev/doc/effective_go)
- [Go Proverbs](https://go-proverbs.github.io)
- [Google Go Style Guide](https://google.github.io/styleguide/go/)
- [Uber Go Style Guide](https://github.com/uber-go/guide/blob/master/style.md)
- [Go Wiki CodeReviewComments](https://github.com/golang/go/wiki/CodeReviewComments)
- [Go Blog](https://go.dev/blog/)
