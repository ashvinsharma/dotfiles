---
name: go-coder
description: Go coding patterns, TDD idioms, error handling, and project conventions for writing production-quality Go code
---

# Go Coder

Production-quality Go code following Google, Uber, Effective Go, and CodeReviewComments style guides.

---

## Style Principles (Priority Order)

Apply in this order when making decisions:

### 1. Clarity
Purpose and rationale must be obvious to the reader — not the author.

```go
// Good: clear purpose, no repetition
func (c *Config) WriteTo(w io.Writer) (int64, error)

// Bad: repeats receiver, confusing return
func (c *Config) WriteConfigTo(w io.Writer) (int64, error)
```

### 2. Simplicity
Least mechanism: prefer core constructs → stdlib → new dependencies.

```go
// Good: use a map, not a custom type
seen := map[string]bool{}

// Bad: inventing abstraction that adds nothing
type StringSet struct{ m map[string]struct{} }
```

### 3. Concision
High signal-to-noise. Avoid extraneous syntax, repetitive code, unnecessary abstraction.

```go
// Good: common idiom is high signal
if err := doSomething(); err != nil {
    return err
}

// Good: signal boost for unusual case
if err := doSomething(); err == nil { // if NO error
    // ...
}
```

### 4. Maintainability
APIs that grow gracefully. Predictable names. Comprehensive tests with clear diagnostics.

### 5. Consistency
When in doubt, match surrounding code. Package-level consistency matters most.

---

## Formatting

- All files **must** pass `gofmt` — no exceptions, no debates
- Use `goimports` to manage import grouping automatically
- No rigid line length limit — if a line feels too long, **refactor** rather than wrap
- When splitting function args, put all on their own lines:

```go
// Bad: arbitrary mid-line break
func (s *Store) GetUser(ctx context.Context,
    id string) (*User, error) {

// Good: all args on own lines
func (s *Store) GetUser(
    ctx context.Context,
    id string,
) (*User, error) {
```

### Reduce Nesting

Handle error/special cases first. Keep the happy path unindented.

```go
// Bad: deeply nested
for _, v := range data {
    if v.F1 == 1 {
        v = process(v)
        if err := v.Call(); err == nil {
            v.Send()
        } else {
            return err
        }
    } else {
        log.Printf("Invalid v: %v", v)
    }
}

// Good: flat structure with early returns
for _, v := range data {
    if v.F1 != 1 {
        log.Printf("Invalid v: %v", v)
        continue
    }
    v = process(v)
    if err := v.Call(); err != nil {
        return err
    }
    v.Send()
}
```

### Unnecessary Else

```go
// Bad
var a int
if b {
    a = 100
} else {
    a = 10
}

// Good: default + override
a := 10
if b {
    a = 100
}
```

### Naked Returns

Fine in small functions. Be explicit in medium+ functions. Don't name results just to enable naked returns.

```go
// Good: small function, naked return is clear
func minMax(a, b int) (min, max int) {
    if a < b { min, max = a, b } else { min, max = b, a }
    return
}

// Good: larger function, explicit return
func processData(data []byte) (result []byte, err error) {
    // ... many lines ...
    return result, nil  // explicit: clearer in longer functions
}
```


---

## Naming

### MixedCaps — Required
Go uses `MixedCaps` or `mixedCaps`. Never underscores or ALL_CAPS.

```go
// Good
MaxLength    // exported constant
maxLength    // unexported constant
userID       // variable

// Bad
MAX_LENGTH   // no snake_case
max_length   // no underscores
```

Exceptions: test function names (`TestFoo_InvalidInput`), generated code, OS/cgo interop.

### Packages
Lowercase, no underscores. Concise. Don't shadow common variables.

```go
// Good: user, oauth2, httputil, tabwriter
// Bad: user_service (underscores), UserService (uppercase), util (generic)
```

Generic names may appear as *part* of a name (`stringutil`) but not as the whole name.

### Initialisms
Consistent case throughout: all-upper or all-lower.

```go
// Good: HTTPClient, userID, ParseURL, XMLAPI
// Bad: HttpClient, userId, ParseUrl
```

### Receivers
Short 1-2 letter abbreviation. Consistent across all methods of that type. Never `this` or `self`.

```go
// Good — consistent
func (c *Client) Connect() error
func (c *Client) Send(msg []byte) error
func (c *Client) Close() error

// Bad — inconsistent and verbose
func (client *Client) Connect() error
func (cl *Client) Send(msg []byte) error
func (this *Client) Close() error
```

### Avoiding Repetition
Names should not feel repetitive when used in context.

```go
// Bad: widget.NewWidget(), p.ProjectName(), db.LoadFromDatabase()
// Good: widget.New(),       p.Name(),        db.Load()
```

### Getters and Setters
No `Get` prefix for simple accessors. Use `SetX` for setters.

```go
// Good
owner := obj.Owner()
obj.SetOwner(user)

// Bad
owner := obj.GetOwner()
```

Use `Compute` or `Fetch` for expensive operations: `db.FetchUser(id)`, `stats.ComputeAverage()`.

### Interface Names
One-method interfaces use `-er` suffix: `Reader`, `Writer`, `Stringer`, `Formatter`.
Honor canonical method names (`Read`, `Write`, `Close`, `String`) and their signatures.

### Constants
MixedCaps. Never ALL_CAPS or K prefix. Name by role, not value.

```go
// Good
const MaxRetries = 3
const DefaultPort = 8080

// Bad
const MAX_RETRIES = 3    // no ALL_CAPS
const kMaxBuffer = 1024  // no K prefix
const Three = 3          // name describes value, not role
```

### Variables
Length should reflect scope size. Short names (`i`, `v`) for small scopes; longer names for larger scopes.

```go
for i, v := range items { ... }           // small scope: short names fine
pendingOrders := filterPending(orders)    // larger scope: descriptive
```

---

## Control Flow

### If with Initialization
Scope variables to the conditional block:

```go
if err := file.Chmod(0664); err != nil {
    log.Print(err)
    return err
}
```

### Redeclaration with :=
`:=` reassigns `err` if already declared in the same scope, as long as at least one new variable is created:

```go
data, err := fetchData()
if err != nil { return err }
result, err := processData(data)  // err reassigned, result declared
if err != nil { return err }
```

Warning: `:=` in an inner scope creates a **new** variable that shadows the outer one.

### Switch
No automatic fallthrough. Cases can be comma-separated. Expression-less switch is idiomatic for ranges:

```go
switch {
case '0' <= c && c <= '9':
    return c - '0'
case 'a' <= c && c <= 'f':
    return c - 'a' + 10
}
```

### For Loops
Go unifies for/while into one construct:

```go
for i := 0; i < n; i++ { }   // C-style
for condition { }              // while-style
for { }                        // infinite
for k, v := range m { }       // range with key+value
for _, v := range slice { }   // range value only
for k := range m { }          // range key only
```


---

## Error Handling

### Return the error Interface — Never Concrete Types
A concrete `nil` pointer can become a non-nil interface value:

```go
// Bad: concrete error type causes subtle nil-interface bugs
func Bad() *os.PathError { ... }

// Good: always return error interface
func Good() error { ... }
```

`error` is the last return parameter by convention.

### Error Strings
Lowercase, no trailing punctuation. Error strings appear within other context before printing.

```go
// Bad
err := fmt.Errorf("Something bad happened.")

// Good
err := fmt.Errorf("something bad happened")
```

Exception: may start with a capital letter if it begins with an exported name, proper noun, or acronym.

### Indent Error Flow
Handle errors first. Never use `else` after an error return.

```go
// Good: normal path unindented
if err != nil {
    return err
}
// normal code

// Bad: normal code buried in else
if err != nil {
    // error handling
} else {
    // normal code that looks abnormal
}
```

### Handle Errors Once
Choose ONE response — never log AND return:

```go
// Bad: logs AND returns — causes duplicate noise up the call stack
u, err := getUser(id)
if err != nil {
    log.Printf("Could not get user %q: %v", id, err)
    return err  // callers will also log this!
}

// Good: wrap and return — let caller decide
u, err := getUser(id)
if err != nil {
    return fmt.Errorf("get user %q: %w", id, err)
}

// Good: log and degrade — when failure is non-fatal
if err := emitMetrics(); err != nil {
    log.Printf("could not emit metrics: %v", err)
}
// continue execution...

// Good: match specific errors, return others
tz, err := getUserTimeZone(id)
if err != nil {
    if errors.Is(err, ErrUserNotFound) {
        tz = time.UTC
    } else {
        return fmt.Errorf("get user %q: %w", id, err)
    }
}
```

### %w vs %v
- `%w`: preserves the error chain for `errors.Is`/`errors.As` — use within a system
- `%v`: hides internal details — use at system boundaries, for logging, or when callers shouldn't inspect

```go
// %w — chain preserved, callers can unwrap
return fmt.Errorf("open config: %w", err)

// %v — chain hidden, opaque error
return fmt.Errorf("open config: %v", err)
```

Place `%w` at the **end**: `"context message: %w"`.

### Sentinel Errors
Use `var ErrFoo = errors.New(...)` at package level for expected failure cases. Check with `errors.Is`, never string matching.

```go
var ErrNotFound = errors.New("not found")

// checking
if errors.Is(err, ErrNotFound) { ... }
```

### Error Type Decision Table

| Caller needs to match? | Message type | Use |
|------------------------|--------------|-----|
| No | static | `errors.New("message")` |
| No | dynamic | `fmt.Errorf("msg: %v", val)` |
| Yes | static | `var ErrFoo = errors.New("...")` |
| Yes | dynamic | custom `error` type |

### Avoid In-Band Errors
Don't return `-1`, `nil`, or `""` to signal errors. Use multiple returns:

```go
// Bad: caller can accidentally chain this
func Lookup(key string) int  // returns -1 on missing

// Good: forces caller to handle the missing case
func Lookup(key string) (value string, ok bool)
```

### Ignoring Errors
If ignoring is appropriate, add a comment explaining why:

```go
n, _ := b.Write(p) // bytes.Buffer.Write never returns a non-nil error
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

### Define at the Point of Use
Interfaces belong in the package that *uses* them, not the package that implements them.

### Keep Interfaces Small
Single-method interfaces are idiomatic. The smaller the interface, the more powerful it is.

```go
// Good: one method, maximum flexibility
type Writer interface {
    Write(p []byte) (n int, err error)
}
```

### Implicit Satisfaction
Types implement interfaces by implementing methods — no `implements` keyword:

```go
type ByteSlice []byte

func (p *ByteSlice) Write(data []byte) (n int, err error) {
    *p = append(*p, data...)
    return len(data), nil
}

var w io.Writer = &ByteSlice{} // ByteSlice now implements io.Writer
```

### Return Interfaces from Constructors (Generality)
If a type exists only to implement an interface, don't export the type — return the interface:

```go
// Good: hides implementation, exposes interface
func NewHash() hash.Hash32 {
    return &myHash{} // unexported type
}
```

### Compile-Time Interface Check
When there's no static conversion to catch it, add a check:

```go
var _ http.Handler = (*Handler)(nil)
var _ json.Marshaler = (*MyType)(nil)
```

Fails at compile time if the type doesn't implement the interface. Don't add for every type — only when there's no other static conversion that would catch the error.

### Type Assertions
Without checking, a failed assertion panics. Always use comma-ok:

```go
// Panics if wrong type
f := w.(*os.File)

// Safe: test before use
f, ok := w.(*os.File)
if ok {
    // use f
}
```

### Type Switch

```go
switch v := value.(type) {
case int:
    fmt.Printf("integer: %d\n", v)  // v is int
case string:
    fmt.Printf("string: %q\n", v)   // v is string
default:
    fmt.Printf("unexpected type %T\n", v)
}
```

Reusing the variable name in the switch expression is idiomatic — it has the correct concrete type in each case.

### Interface Embedding
Combine interfaces by embedding:

```go
type ReadWriter interface {
    Reader
    Writer
}
```

### Struct Embedding
Promotes methods from inner type to outer type — Go's alternative to inheritance:

```go
// bufio.ReadWriter: methods from both Reader and Writer are promoted
type ReadWriter struct {
    *Reader
    *Writer
}
```

When an embedded method is invoked, the receiver is the *inner* type, not the outer one.

### Receiver Type Selection
When in doubt, use a pointer receiver. Rules:

| Use pointer receiver when... | Use value receiver when... |
|------------------------------|----------------------------|
| Method mutates receiver | Small unchanging structs |
| Contains `sync.Mutex` or similar | Map, func, or chan fields |
| Large struct or array | No mutable fields, no pointers |
| Changes must be visible in original | Simple basic types (int, string) |

**Consistency rule**: Don't mix receiver types. If any method needs a pointer receiver, use pointer receivers for all methods on that type.


---

## Concurrency

### Never Start a Goroutine Without Knowing How It Will Stop
Goroutines can leak by blocking on channel sends/receives. The GC will **not** terminate a blocked goroutine.

```go
// Bad: no way to stop or wait
go func() {
    for {
        flush()
        time.Sleep(delay)
    }
}()

// Good: controlled shutdown with stop/done channels
stop := make(chan struct{})
done := make(chan struct{})
go func() {
    defer close(done)
    ticker := time.NewTicker(delay)
    defer ticker.Stop()
    for {
        select {
        case <-ticker.C:
            flush()
        case <-stop:
            return
        }
    }
}()
// To shut down:
close(stop)
<-done
```

### Goroutine Lifetimes Must Be Obvious

```go
// Good: goroutine lifetime is scoped to the function
func (w *Worker) Run(ctx context.Context) error {
    var wg sync.WaitGroup
    for item := range w.q {
        wg.Add(1)
        go func() {
            defer wg.Done()
            process(ctx, item)
        }()
    }
    wg.Wait()
    return nil
}
```

### No Goroutines in init()
Expose an object with a `Shutdown`/`Stop`/`Close` method instead:

```go
// Bad
func init() { go doWork() }

// Good
type Worker struct{ stop, done chan struct{} }

func NewWorker() *Worker {
    w := &Worker{stop: make(chan struct{}), done: make(chan struct{})}
    go w.run()
    return w
}

func (w *Worker) Shutdown() { close(w.stop); <-w.done }
```

### Waiting for Goroutines

```go
// Multiple goroutines: WaitGroup
var wg sync.WaitGroup
for i := 0; i < N; i++ {
    wg.Add(1)
    go func() { defer wg.Done(); /* work */ }()
}
wg.Wait()

// Single goroutine: done channel
done := make(chan struct{})
go func() { defer close(done); /* work */ }()
<-done
```

### Prefer Synchronous Functions
Let the caller add concurrency when needed — don't force it:

```go
// Good: synchronous, caller controls concurrency
func ProcessItems(items []Item) ([]Result, error) { ... }

// Caller adds concurrency if needed:
go func() { results, err := ProcessItems(items) }()
```

### Mutex Rules
Zero-value `sync.Mutex` is valid — no need for a pointer. Never embed a mutex in a struct (it leaks `Lock`/`Unlock` into the API):

```go
// Bad: embedded mutex leaks Lock/Unlock as public methods
type SMap struct {
    sync.Mutex
    data map[string]string
}

// Good: named field keeps it as implementation detail
type SMap struct {
    mu   sync.Mutex
    data map[string]string
}
```

### Channel Direction
Always specify direction — prevents accidental misuse and conveys ownership:

```go
func produce(out chan<- int) { /* send-only */ }
func consume(in <-chan int)  { /* receive-only */ }
```

### Channel Sizing
Default to 0 (unbuffered) or 1. Any other size needs explicit justification explaining what prevents it from filling and what happens when writers block.

```go
c := make(chan int)    // unbuffered
c := make(chan int, 1) // size of one

// Bad: arbitrary buffer
c := make(chan int, 64) // "ought to be enough for anybody"
```

### Context for Cancellation

```go
// Derive with timeout
ctx, cancel := context.WithTimeout(ctx, 5*time.Second)
defer cancel()

// Check cancellation in long-running loops
for {
    select {
    case <-ctx.Done():
        return ctx.Err()
    default:
        // do work
    }
}
```

### Atomic Operations
Use `go.uber.org/atomic` for type-safe atomics — raw `sync/atomic` makes it easy to accidentally read non-atomically:

```go
// Bad: easy to forget the atomic read
type foo struct{ running int32 }
func (f *foo) isRunning() bool { return f.running == 1 } // race!

// Good: type-safe, impossible to accidentally read raw
type foo struct{ running atomic.Bool }
func (f *foo) isRunning() bool { return f.running.Load() }
```

### Goroutine Leak Detection
Use `go.uber.org/goleak` in tests for packages that spawn goroutines.

### Concurrency Checklist
Before spawning a goroutine:
- [ ] How will this goroutine exit?
- [ ] Can I signal it to stop?
- [ ] Can I wait for it to finish?
- [ ] Who owns the channels it uses?
- [ ] What happens when the context is cancelled?
- [ ] Should this be a synchronous function instead?


---

## Context

### Context is Always the First Parameter

```go
func F(ctx context.Context, /* other arguments */) error { ... }
func ProcessRequest(ctx context.Context, req *Request) (*Response, error) { ... }
```

### Never Store Context in Structs
Pass `ctx` as a parameter to each method that needs it:

```go
// Bad
type Worker struct {
    ctx context.Context // lifetime unclear
}

// Good
type Worker struct{}

func (w *Worker) Process(ctx context.Context) error { ... }
```

Exception: methods whose signature must match a third-party interface.

### Don't Create Custom Context Types
Use `context.Context` — not custom interfaces that extend it.

### What Belongs in Context Values
Appropriate: request IDs, trace IDs, auth info that flows with requests.
Not appropriate: optional function parameters, config that doesn't vary per-request, data that could be passed explicitly.

Prefer explicit parameters first, then receiver fields, then context values as a last resort.

### context.Background()
Use only for non-request-specific code (main, init, top-level tests). Default to accepting and passing a context even if you don't use it now — it avoids a future API break.

```go
func main() {
    ctx := context.Background()
    if err := run(ctx); err != nil { log.Fatal(err) }
}
```

### Context Immutability
Safe to pass the same ctx to multiple calls — contexts are immutable:

```go
g, ctx := errgroup.WithContext(ctx)
g.Go(func() error { return processA(ctx, a) })
g.Go(func() error { return processB(ctx, b) })
return g.Wait()
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
// Good: stdlib style
if got := Add(2, 3); got != 5 {
    t.Errorf("Add(2, 3) = %d, want %d", got, 5)
}

// Good: testify style
assert.Equal(t, 5, Add(2, 3), "Add(2, 3)")
```

### Struct Comparison with cmp.Diff
For complex types, use `cmp.Diff` (or `assert.Equal` with testify):

```go
// stdlib
want := &Doc{Type: "blogPost", Authors: []string{"isaac"}}
if diff := cmp.Diff(want, got); diff != "" {
    t.Errorf("AddPost() mismatch (-want +got):\n%s", diff)
}

// testify
assert.Equal(t, want, got)
```

### t.Error vs t.Fatal
- `t.Error` / `assert.Error`: keeps the test running — report all failures in one run
- `t.Fatal` / `require.NoError`: stops the test immediately — use when continuation is meaningless

```go
// Good: t.Fatal on setup failure (no point continuing)
gotEncoded := Encode(input)
if gotEncoded != wantEncoded {
    t.Fatalf("Encode(%q) = %q, want %q", input, gotEncoded, wantEncoded)
}
// decoding unexpected output would be meaningless

// Good: testify/require equivalent
require.Equal(t, wantEncoded, gotEncoded)
```

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

func setupTestDB(t *testing.T) *sql.DB {
    t.Helper()
    db, err := sql.Open("sqlite3", ":memory:")
    if err != nil {
        t.Fatalf("Could not open database: %v", err)
    }
    t.Cleanup(func() { db.Close() }) // use t.Cleanup, not defer
    return db
}
```

### Table-Driven Tests
Use when many cases share identical logic (no conditional assertions or branching per case):

```go
func TestCompare(t *testing.T) {
    tests := []struct {
        name    string
        a, b    string
        want    int
    }{
        {"equal", "abc", "abc", 0},
        {"a_greater", "b", "a", 1},
        {"b_greater", "a", "b", -1},
    }
    for _, tt := range tests {
        t.Run(tt.name, func(t *testing.T) {
            got := Compare(tt.a, tt.b)
            if got != tt.want {
                t.Errorf("Compare(%q, %q) = %v, want %v", tt.a, tt.b, got, tt.want)
            }
        })
    }
}
```

When cases need complex setup, conditional mocking, or multiple branches — use separate test functions instead.

### Parallel Tests
In Go 1.22+, loop variables are correctly captured per iteration. In Go 1.21 and earlier, add `tt := tt` before `t.Parallel()`:

```go
for _, tt := range tests {
    t.Run(tt.name, func(t *testing.T) {
        t.Parallel()
        // Go 1.22+: safe. Go <=1.21: add "tt := tt" before this line
        got := Process(tt.give)
        assert.Equal(t, tt.want, got)
    })
}
```

### Test Error Semantics — Not Strings

```go
// Bad: brittle string comparison
if err.Error() != "invalid input" { ... }

// Good: semantic error check
if !errors.Is(err, ErrInvalidInput) {
    t.Errorf("got error %v, want ErrInvalidInput", err)
}
```

### Test Packages
`package foo` — same-package tests, accesses unexported identifiers.
`package foo_test` — black-box tests, avoids circular dependencies.

### Scoped Setup
Keep setup scoped to tests that need it. Avoid `init()` or global `var` for test data — it runs for all tests even unrelated ones.

### Test Doubles Naming
Package: append `test` to production package (e.g., `creditcardtest`).
Variables: prefix with the double type (`spyCC`, `stubSvc`).


---

## Documentation

### Doc Comments — Required for All Exported Names
Begin with the name of the object. Use full sentences (capitalized, punctuated).

```go
// A Request represents a request to run a command.
type Request struct { ... }

// Encode writes the JSON encoding of req to w.
func Encode(w io.Writer, req *Request) { ... }
```

### Package Comments
One per package, above the `package` clause. For long comments, use `doc.go`.

```go
// Package math provides basic constants and mathematical functions.
//
// This package does not guarantee bit-identical results across architectures.
package math
```

### Document Non-Obvious Behavior Only
Don't restate what the signature already says. Document edge cases, error conditions, and requirements:

```go
// Bad: restates the obvious
// format is the format, and data is the interpolation data.

// Good: documents non-obvious behavior
// If the data does not match the expected format verbs, the function
// will inline warnings about formatting errors into the output string.
```

### Document Cleanup Requirements

```go
// NewTicker returns a new Ticker.
//
// Call Stop to release the Ticker's associated resources when done.
func NewTicker(d Duration) *Ticker
```

### Document Sentinel Error Values and Types

```go
// Read reads up to len(b) bytes from the File.
//
// At end of file, Read returns 0, io.EOF.
func (*File) Read(b []byte) (n int, err error)

// Chdir changes the current working directory.
//
// If there is an error, it will be of type *PathError.
func Chdir(dir string) error
```

Note `*PathError` (pointer), not `PathError` — enables correct `errors.As` usage.

### Context Cancellation in Docs
Don't document that a function returns `ctx.Err()` on cancellation — that's implied. Document when behavior *differs*:

```go
// Good: non-standard cancellation behavior
// Run executes the worker's run loop.
//
// If the context is cancelled, Run returns a nil error.
func (Worker) Run(ctx context.Context) error
```

### Concurrency Documentation
Read-only is assumed safe; mutating is assumed unsafe. Document when it's ambiguous or non-standard:

```go
// Lookup returns the data associated with the key from the cache.
//
// This operation is not safe for concurrent use.
func (*Cache) Lookup(key string) (data []byte, ok bool)
```

### Named Return Parameters
Use when multiple params share the same type, or when the name adds clarity:

```go
// Good: multiple same-type params
func (n *Node) Children() (left, right *Node, err error)

// Good: cancel function name explains usage
func WithTimeout(parent Context, d time.Duration) (ctx Context, cancel func())

// Bad: type already tells the story
func (n *Node) Parent1() (node *Node)  // just return *Node
```

### Godoc Formatting
Separate paragraphs with blank lines. Indent code blocks by two additional spaces.

```go
// Update runs the function in an atomic transaction.
//
// This is typically used with an anonymous TransactionFunc:
//
//   if err := db.Update(func(state *State) { state.Foo = bar }); err != nil {
//     // handle error
//   }
func (db *DB) Update(fn TransactionFunc) error
```

### Signal Boosting
Add comments to highlight unusual patterns that look like common ones:

```go
if err := doSomething(); err == nil { // if NO error
    // ...
}
```


---

## Data Structures

### new vs make
- `new(T)`: allocates zeroed storage, returns `*T`. Works for any type.
- `make(T, args)`: initializes slices, maps, and channels only. Returns `T` (not `*T`).

```go
var p *[]int = new([]int)       // *p == nil; rarely useful
var v  []int = make([]int, 100) // v is a usable 100-element slice

// Idiomatic:
v := make([]int, 100)
m := make(map[string]int)
```

### Zero-Value Design
Design structs so the zero value is immediately useful without further initialization:

```go
type SyncedBuffer struct {
    lock   sync.Mutex  // zero value is valid
    buffer bytes.Buffer // zero value is valid
}
// Ready to use immediately — no constructor needed
```

### Declaring Empty Slices
Prefer nil slice over empty slice:

```go
// Good: nil slice (preferred style)
var t []string

// Acceptable: non-nil, zero-length (only when JSON array "[]" is required)
t := []string{}
```

A nil slice encodes to JSON `null`; an empty slice encodes to `[]`. Design interfaces to treat them the same.

### Slice Append
Always assign the result — the underlying array may change:

```go
x := []int{1, 2, 3}
x = append(x, 4, 5, 6)

// Append a slice to a slice
x = append(x, y...)
```

### Map Presence Check
Use comma-ok to distinguish missing from zero value:

```go
seconds, ok := timeZone[tz]
if !ok {
    log.Println("unknown time zone:", tz)
}
```

### Do Not Copy Types with Pointer Semantics
Don't copy `T` if its methods are on `*T`. This applies to:
- `bytes.Buffer`
- `sync.Mutex`, `sync.WaitGroup`, `sync.Cond`
- Any struct embedding the above

```go
// Bad: copying a mutex is almost always a bug
mu2 := mu

// Bad: buf2's internal slice may alias buf1's array
buf2 := buf1
```

### iota Enumerator

```go
type ByteSize float64

const (
    _           = iota // ignore first value
    KB ByteSize = 1 << (10 * iota)
    MB
    GB
    TB
)
```

---

## Defensive Patterns

### Interface Compliance Checks

```go
var _ http.Handler = (*Handler)(nil)   // pointer type
var _ json.Marshaler = (*MyType)(nil)
var _ io.Writer = MyWriter{}           // value type
```

### Copy Slices and Maps at API Boundaries
Slices and maps contain pointers — copy to prevent unintended mutation:

```go
// Receiving: copy before storing
func (d *Driver) SetTrips(trips []Trip) {
    d.trips = make([]Trip, len(trips))
    copy(d.trips, trips)
}

// Returning: return a copy, not internal state
func (s *Stats) Snapshot() map[string]int {
    s.mu.Lock()
    defer s.mu.Unlock()
    result := make(map[string]int, len(s.counters))
    for k, v := range s.counters {
        result[k] = v
    }
    return result
}
```

### Use defer for Cleanup
Place `defer` immediately after acquiring the resource:

```go
f, err := os.Open(filename)
if err != nil { return "", err }
defer f.Close() // close sits near open — much clearer

p.Lock()
defer p.Unlock()
```

Defer overhead is negligible. Only avoid in nanosecond-critical hot paths. Multiple defers execute LIFO. Arguments are evaluated at the `defer` statement, not at call time.

### Start Enums at iota+1
So the zero value means "uninitialized":

```go
// Bad: Add=0 looks valid but might be uninitialized
const (
    Add Operation = iota
    Subtract
)

// Good: zero means uninitialized
const (
    Add Operation = iota + 1
    Subtract
)
```

Exception: when zero is the sensible default (e.g., `LogToStdout = iota`).

### Use time.Time and time.Duration
Never use raw `int` for time values:

```go
// Bad: is delay in ms? seconds?
func poll(delay int) { time.Sleep(time.Duration(delay) * time.Millisecond) }
poll(10)

// Good: self-documenting
func poll(delay time.Duration) { time.Sleep(delay) }
poll(10 * time.Second)
```

When `time.Duration` isn't possible in a struct (e.g., config), include the unit in the field name: `IntervalMillis int`.

### Dependency Injection Over Mutable Globals

```go
// Bad: global makes testing require save/restore
var _timeNow = time.Now
func sign(msg string) string { now := _timeNow(); ... }

// Good: inject the dependency
type signer struct{ now func() time.Time }
func newSigner() *signer { return &signer{now: time.Now} }
func (s *signer) Sign(msg string) string { now := s.now(); ... }

// Test: inject cleanly
s := newSigner()
s.now = func() time.Time { return fixedTime }
```

### Don't Embed Types in Public Structs
Embedding leaks implementation details and inhibits type evolution:

```go
// Bad: adding/removing methods from AbstractList is a breaking change
type ConcreteList struct{ *AbstractList }

// Good: explicit delegation
type ConcreteList struct{ list *AbstractList }
func (l *ConcreteList) Add(e Entity)    { l.list.Add(e) }
func (l *ConcreteList) Remove(e Entity) { l.list.Remove(e) }
```

### Always Use Field Tags on Marshaled Structs

```go
// Bad: renaming Name breaks serialization contract
type Stock struct {
    Price int
    Name  string
}

// Good: explicit tags, safe to rename fields
type Stock struct {
    Price int    `json:"price"`
    Name  string `json:"name"`
}
```

### Use crypto/rand for Key Generation
Never use `math/rand` — even time-seeded, it has predictable output:

```go
import "crypto/rand"

func Key() string {
    return rand.Text()
}
```

### Panic and Recover
Use `panic` only for truly unrecoverable situations. Library functions should avoid panic — if it can be worked around, return an error. Never expose panics across package boundaries:

```go
// Recover in server goroutine handlers to prevent one request from crashing the server
func safeHandler(h http.Handler) http.Handler {
    return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
        defer func() {
            if err := recover(); err != nil {
                log.Printf("panic: %v", err)
                http.Error(w, "internal error", http.StatusInternalServerError)
            }
        }()
        h.ServeHTTP(w, r)
    })
}
```


---

## Packages and Project Layout

### Standard Layout
`cmd/` for binaries, `internal/` for packages not meant for external import, `pkg/` for reusable public packages.

### Avoid Generic Package Names
`util`, `common`, `helper`, `model`, `base` as full package names make code harder to read and cause import conflicts. Use specific names: `stringutil`, `httpauth`, `configloader`.

### Package Size
Combine packages when client code needs two types to interact. Split when something is conceptually distinct and the `pkg.Type` combination is meaningful (`bytes.Buffer`, `ring.New`).

### Import Grouping
Three groups, blank line between each: stdlib → external → internal.

```go
import (
    "fmt"
    "os"

    "go.uber.org/zap"
    "golang.org/x/sync/errgroup"

    "github.com/myorg/myapp/internal/config"
)
```

Use `goimports` to manage this automatically.

### Import Renaming
Only when necessary to avoid collisions. Prefer renaming the most local/project-specific import. Local name must follow package naming rules (no underscores).

```go
// Proto packages: remove underscores, add pb suffix
import foosvcpb "path/to/foo_service_go_proto"

// When url variable name would shadow the package
import urlpkg "net/url"
```

### Blank Imports
`import _ "pkg"` only in main packages or tests — makes clear the import is for side effects only:

```go
import _ "image/png"      // registers PNG decoder
import _ "net/http/pprof" // registers HTTP handlers
```

### Dot Imports
Never use `import .` except for circular test dependencies (where the test file can't be in the package being tested due to import cycles).

### Avoid init()
`init()` makes code harder to test and reason about. If unavoidable, it must be:
- Completely deterministic
- Independent of other `init()` execution order
- Free of I/O, env vars, global state mutation

```go
// Bad: I/O and environment dependencies in init()
func init() {
    raw, _ := os.ReadFile("config.yaml")
    yaml.Unmarshal(raw, &_config)
}

// Good: explicit constructor that returns an error
func loadConfig() (Config, error) {
    raw, err := os.ReadFile("config.yaml")
    if err != nil { return Config{}, err }
    var c Config
    return c, yaml.Unmarshal(raw, &c)
}
```

### Exit Only in main()
`os.Exit` and `log.Fatal` in library functions skip defers, make testing impossible, and create non-obvious control flow. Use the `run()` pattern:

```go
// Good: single exit point, all logic is testable
func main() {
    if err := run(); err != nil {
        log.Fatal(err)
    }
}

func run() error {
    args := os.Args[1:]
    if len(args) != 1 {
        return errors.New("missing file")
    }
    f, err := os.Open(args[0])
    if err != nil { return err }
    defer f.Close() // always runs
    // ...
    return nil
}
```

---

## Functional Options

Use when a constructor or API has 3+ optional parameters, or when the API needs to grow without breaking callers.

```go
// The pattern: unexported options struct + exported Option interface
type options struct {
    cache  bool
    logger *zap.Logger
}

type Option interface {
    apply(*options)
}

// Simple type alias for bool options
type cacheOption bool
func (c cacheOption) apply(opts *options) { opts.cache = bool(c) }
func WithCache(c bool) Option             { return cacheOption(c) }

// Struct for pointer options
type loggerOption struct{ Log *zap.Logger }
func (l loggerOption) apply(opts *options) { opts.logger = l.Log }
func WithLogger(log *zap.Logger) Option    { return loggerOption{Log: log} }

// Constructor: set defaults, then apply options
func Open(addr string, opts ...Option) (*Connection, error) {
    o := options{cache: true, logger: zap.NewNop()}
    for _, opt := range opts {
        opt.apply(&o)
    }
    // ...
}
```

Caller experience:

```go
// Only specify what differs from defaults
db.Open(addr)
db.Open(addr, db.WithLogger(log))
db.Open(addr, db.WithCache(false), db.WithLogger(log))
```

### Interface vs Closure Approach
The closure approach is simpler and common in the wild:

```go
// Closure approach — less boilerplate, widely used
type Option func(*options)

func WithCache(c bool) Option {
    return func(o *options) { o.cache = c }
}
```

The interface approach adds boilerplate but has real advantages for public APIs:
- **Comparable in tests**: closure functions are not comparable in Go, so `assert.Equal(t, WithCache(true), WithCache(true))` fails with closures but works with the interface approach
- **Debuggable**: option types can implement `fmt.Stringer`, making log output readable (`WithCache(true)`) instead of a memory address (`0x10b2340`)
- **Self-documenting**: each `With*` function returns a distinct named type visible in godoc

**Practical guidance**: use closures for internal APIs or when you have fewer than ~5 options. Use the interface approach for public APIs that need testability or will appear in documentation.

### When to Use Config Struct Instead
Fewer than 3 options, all options usually specified together, or internal-only API.

### Functional Options Checklist
- [ ] `options` struct is unexported
- [ ] `Option` interface has unexported `apply` method
- [ ] Each option has a `With*` constructor
- [ ] Defaults are set **before** applying options
- [ ] Required parameters are separate from `...Option`


---

## Performance

Apply these patterns only on the **hot path**. Don't prematurely optimize.

### strconv over fmt for Primitive Conversions
`strconv` is ~2x faster than `fmt` for int-to-string conversions:

```go
// Bad: ~143 ns/op, 2 allocs
s := fmt.Sprint(rand.Int())

// Good: ~64 ns/op, 1 alloc
s := strconv.Itoa(rand.Int())
```

### Avoid Repeated String-to-Byte Conversions
Convert once outside loops (~7x faster):

```go
// Bad: allocates new []byte on each iteration
for i := 0; i < n; i++ {
    w.Write([]byte("Hello world"))
}

// Good: convert once
data := []byte("Hello world")
for i := 0; i < n; i++ {
    w.Write(data)
}
```

### Prefer strings.Builder for String Concatenation in Loops
Using `+` to concatenate strings in a loop creates a new allocation on every iteration — O(n²) total allocations. Use `strings.Builder` instead:

```go
// Bad: O(n²) allocations — each + copies the entire string so far
result := ""
for _, s := range items {
    result += s + ", "
}

// Good: single backing buffer, amortized O(n)
var b strings.Builder
for _, s := range items {
    b.WriteString(s)
    b.WriteString(", ")
}
result := b.String()
```

For known small counts (2-3 strings), `+` is fine — the compiler optimizes it. Use `strings.Builder` when iterating over a collection of unknown size.

### Pre-allocate Containers with Known Size
Specifying capacity avoids reallocations during growth (~12x faster for slices):

```go
// Bad: map/slice grow dynamically
m := make(map[string]os.DirEntry)
data := make([]int, 0)

// Good: right-sized from the start
m := make(map[string]os.DirEntry, len(files))
data := make([]int, 0, size)
```

Note: map capacity is a hint (approximates bucket count); slice capacity is exact.

### Pass Values, Not Pointers, for Small Fixed-Size Types
Don't pass `*string` or `*io.Reader` just to avoid a copy — they're already small headers (16 bytes). Pointers add a layer of indirection and a potential cache miss:

```go
// Bad: pointer to string adds indirection for no benefit
func process(s *string) { fmt.Println(*s) }

// Good: pass string directly
func process(s string) { fmt.Println(s) }
```

**Important exception — nullable/optional fields**: `*string` is legitimate when `nil` carries semantic meaning (field not set vs field set to empty string). This is common in generated API structs, config types, and SDK clients (e.g., AWS SDK uses `*string` throughout to distinguish "not provided" from `""`). Don't flag `*string` in these contexts — the pointer is intentional.

```go
// Legitimate: nil means "not configured", "" means "explicitly empty"
type Config struct {
    Region   *string // nil = use default
    Endpoint *string // nil = use default
}
```

Other exceptions: large structs where copy cost is significant, or small structs that may grow.

---

## Linting

### Core Principle
More important than any specific linter set: **lint consistently across the entire codebase**.

### Agent Instruction
After writing or modifying Go code, **always** attempt to run `golangci-lint run ./...`.

- If `golangci-lint` is not found: warn the user and recommend installing it before proceeding
- If no `.golangci.yml` exists: warn the user and offer to create a starter config
- Never silently skip linting

```bash
# Check if installed
which golangci-lint || echo "WARNING: golangci-lint not found"

# Install if missing
go install github.com/golangci/golangci-lint/cmd/golangci-lint@latest

# Run
golangci-lint run ./...
```

### Minimum Recommended Linters

| Linter | Purpose |
|--------|---------|
| `errcheck` | Ensures errors are handled |
| `goimports` | Formats code and manages imports |
| `revive` | Common style mistakes (successor to `golint`) |
| `govet` | Analyzes code for common mistakes |
| `staticcheck` | Various static analysis checks |

Starter `.golangci.yml` to offer when none exists:

```yaml
linters:
  enable:
    - errcheck
    - goimports
    - revive
    - govet
    - staticcheck

linters-settings:
  goimports:
    local-prefixes: github.com/your-org/your-repo

run:
  timeout: 5m
```

---

## Commit Checklist

Before proposing any commit:

1. `gofmt -l .` — returns no output
2. `go build ./...` — succeeds
3. `go test -race ./...` — passes
4. `golangci-lint run ./...` — clean (warn user and recommend install if not found)
5. No unused imports or variables

---

## Authoritative Sources

- [Effective Go](https://go.dev/doc/effective_go)
- [Google Go Style Guide](https://google.github.io/styleguide/go/)
- [Uber Go Style Guide](https://github.com/uber-go/guide/blob/master/style.md)
- [Go Wiki CodeReviewComments](https://github.com/golang/go/wiki/CodeReviewComments)
- [Dave Cheney: Never start a goroutine without knowing how it will stop](https://dave.cheney.net/2016/12/22/never-start-a-goroutine-without-knowing-how-it-will-stop)
- [Dave Cheney: Functional options for friendly APIs](https://dave.cheney.net/2014/10/17/functional-options-for-friendly-apis)
