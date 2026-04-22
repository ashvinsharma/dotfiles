---
name: go-security
description: Go-specific security antipatterns for use by security-reviewer — TLS misconfiguration, injection, unsafe usage, credential leaks, race conditions in auth paths
---

# Go Security

Security antipatterns specific to Go. Loaded by the `security-reviewer` agent to complement its language-agnostic checks. Do not use severity levels from the code reviewer — use CRITICAL / HIGH / MEDIUM / LOW based on exploitability and impact.

---

## TLS and Cryptography

**CRITICAL — `InsecureSkipVerify: true`**
`tls.Config{InsecureSkipVerify: true}` disables certificate chain and hostname verification entirely. Any code reaching production with this set is trivially MITM-able.
Reference: https://pkg.go.dev/crypto/tls#Config

**CRITICAL — `math/rand` for security-sensitive values**
`math/rand` is a pseudo-random number generator seeded deterministically. Any token, nonce, session ID, or secret generated with it is predictable. Require `crypto/rand`.

**HIGH — Weak cipher suites**
Manual `CipherSuites` lists containing `TLS_RSA_WITH_RC4_128_SHA`, any `RC4`, `3DES`, or `NULL` cipher are broken. Go's default cipher list is safe — flag any manual override that weakens it.

**HIGH — Minimum TLS version below 1.2**
`tls.Config{MinVersion: tls.VersionTLS10}` or `tls.VersionTLS11` must be rejected. Minimum version must be `tls.VersionTLS12`; prefer `tls.VersionTLS13`.

**HIGH — Unconditional nil from `VerifyPeerCertificate`**
A custom `tls.Config.VerifyPeerCertificate` function that always returns `nil` silently bypasses certificate validation.

**HIGH — MD5 or SHA-1 for security-sensitive hashing**
`crypto/md5` and `crypto/sha1` are broken for password hashing and HMAC. Acceptable only for non-security checksums (e.g., ETag generation) with an explicit comment stating it is not security-sensitive.

---

## SQL Injection

**CRITICAL — String concatenation in `database/sql`**
Any query constructed via string concatenation or `fmt.Sprintf` with user-supplied input:
```go
// REJECT
db.Query("SELECT * FROM users WHERE name = '" + name + "'")
db.Query(fmt.Sprintf("SELECT * FROM users WHERE id = %s", id))

// REQUIRE
db.Query("SELECT * FROM users WHERE name = ?", name)
```

**CRITICAL — ORM raw queries with user input**
`db.Raw(fmt.Sprintf(...))`, `gorm.Exec(fmt.Sprintf(...))`, or any ORM escape hatch that accepts a string-formatted with user data must be rejected.

---

## Command Injection

**CRITICAL — Shell form with user-controlled input**
`exec.Command("sh", "-c", userInput)` or `exec.Command("bash", "-c", userInput)` where the argument to `-c` is derived from user-controlled data. Always use the argument-list form:
```go
// REJECT
exec.Command("sh", "-c", "process "+userInput)

// REQUIRE
exec.Command("process", userInput)
```

**HIGH — `os.Expand` or string interpolation into shell strings**
Using `os.Expand`, `strings.Replace`, or `fmt.Sprintf` to interpolate user input into a string that is subsequently passed to a shell executor.

---

## `unsafe` Package

**HIGH — Unrelated-type pointer casts without documented invariant**
`unsafe.Pointer` casts between unrelated types must have a comment explaining: (a) why `unsafe` is necessary, (b) what invariant makes it safe, and (c) a reference to the relevant rule in the unsafe package docs (https://pkg.go.dev/unsafe).

**HIGH — `reflect.SliceHeader` / `reflect.StringHeader` for raw pointer construction**
Constructing slices or strings from raw pointers via these types without explicit bounds documentation and size validation.

---

## Hardcoded Credentials

**CRITICAL — Credential literals**
String literals assigned to variables whose names contain (case-insensitive): `password`, `passwd`, `secret`, `token`, `apikey`, `api_key`, `credential`, `auth`, `private_key`, `access_key`. Require `os.Getenv` or a secrets manager.

**HIGH — Base64-encoded secrets**
Base64-encoded strings longer than 40 characters in string literals assigned to security-relevant variable names (see above list).

---

## HTTP Security

**HIGH — Path traversal**
HTTP handlers that read user-controlled input (query param, form field, JSON body, header) and use it in file path operations without both `filepath.Clean` and an allowlist prefix check:
```go
// REJECT
http.ServeFile(w, r, basePath+r.URL.Query().Get("file"))

// REQUIRE
clean := filepath.Clean(filepath.Join(basePath, r.URL.Query().Get("file")))
if !strings.HasPrefix(clean, basePath) {
    http.Error(w, "forbidden", http.StatusForbidden)
    return
}
```

**HIGH — SSRF**
HTTP handlers that make outbound requests to URLs derived from user input without a scheme allowlist (`https` only) and a host allowlist or CIDR block check. Block `localhost`, `127.0.0.1`, `169.254.169.254` (AWS metadata) explicitly.

**MEDIUM — Missing request body size limit**
`http.MaxBytesReader` must wrap the request body in handlers that read it. Without this, a slow client can hold a connection open indefinitely or exhaust memory.

**MEDIUM — Missing HTTP server timeouts**
An `http.Server` without `ReadTimeout`, `WriteTimeout`, and `IdleTimeout` is vulnerable to resource exhaustion via slow clients. These are not security-critical in dev but must be set in production-bound code.

---

## TOCTOU Race Conditions in Auth

**HIGH — Check-then-act without synchronization**
Auth checks followed by resource access where the state can change between the check and the act in a concurrent context:
```go
// REJECT — isAuthorized may return stale data
if isAuthorized(userID) {
    doPrivilegedAction(userID)
}
```
The check and action must either hold a lock across both operations or re-validate inside the critical section.

---

## Goroutine Leaks in Security-Sensitive Paths

**HIGH — Goroutines in auth handlers without context propagation**
Goroutines launched inside auth handlers, middleware, or request-scoped security checks that do not propagate `context.Context` for cancellation. A leaked goroutine may hold a capability, token, or session reference beyond its intended lifetime.

---

## JWT and Token Handling

**CRITICAL — `alg:none` or unsigned token acceptance**
JWT libraries configured to accept tokens signed with `alg: none` or with signature validation disabled.

**HIGH — Incomplete JWT validation**
Validating only token expiry without also checking issuer (`iss`), audience (`aud`), and cryptographic signature.

**MEDIUM — Tokens in logs or error responses**
JWT strings, session tokens, or bearer tokens written to log output or returned in error responses. These end up in log aggregation systems accessible beyond the intended audience.

---

## Authoritative References

- Go crypto/tls: https://pkg.go.dev/crypto/tls
- Go unsafe rules: https://pkg.go.dev/unsafe
- OWASP Go Secure Coding Practices: https://owasp.org/www-project-go-secure-coding-practices-guide/
- OSV vulnerability database: https://osv.dev
- Go SQL injection prevention: https://go.dev/doc/database/sql
