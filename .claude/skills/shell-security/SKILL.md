---
name: shell-security
description: Shell/Bash-specific security antipatterns for use by security-reviewer — injection, path traversal, credential leaks, insecure temp files, missing input validation
---

# Shell Security

Security antipatterns specific to Shell/Bash. Loaded by the `security-reviewer` agent. Use CRITICAL / HIGH / MEDIUM / LOW based on exploitability and impact.

---

## Injection via Unquoted Variables

**CRITICAL — Unquoted variable in command**
Any variable used in a command without double quotes undergoes word splitting and glob expansion. If the value is attacker-controlled, this enables command injection:
```bash
# REJECT — word splitting turns "foo bar" into two arguments; glob turns "*.txt" into file list
rm $file
cp $src $dst
find $dir -name $pattern

# REQUIRE
rm "$file"
cp "$src" "$dst"
find "$dir" -name "$pattern"
```

**CRITICAL — Unquoted variable in sensitive tools**
Variables used without quoting in `find`, `xargs`, `ssh`, `curl`, `wget`, `rsync`, `tar` arguments where the value originates from user input, environment variables, or external data sources.

---

## `eval` and Dynamic Execution

**CRITICAL — `eval` with user-controlled input**
`eval "$user_input"` or `eval "$(command_producing_user_data)"` executes arbitrary shell commands. There is no safe way to use `eval` with untrusted input.

**CRITICAL — `source` / `.` on user-provided paths**
`source "$user_path"` or `. "$user_path"` executes the file as shell code. Must only be used with paths that are fully controlled and validated (e.g., known config files under a trusted prefix).

---

## Command Injection via Interpolation

**CRITICAL — User input in command substitution**
Backtick or `$()` substitutions where the inner command is constructed from user-controlled data:
```bash
# REJECT
output=$(ssh "$host" "$user_cmd")
result=`process $user_arg`

# REQUIRE — validate and allowlist $user_arg before use
```

**HIGH — Unescaped interpolation in here-documents passed to shell**
Here-documents that include user-controlled variables and are piped to `sh`, `bash`, or `eval`.

---

## Path Traversal

**HIGH — User-supplied path in file operations without validation**
User-supplied paths used with `cp`, `mv`, `rm`, `cat`, `chmod`, `chown`, `ln` without stripping `../` and validating the result stays within an allowed prefix:
```bash
# REJECT
cat "$BASE_DIR/$user_path"

# REQUIRE
real=$(realpath "$BASE_DIR/$user_path" 2>/dev/null) || { echo "invalid path"; exit 1; }
case "$real" in
  "$BASE_DIR"/*) ;;
  *) echo "path traversal attempt"; exit 1 ;;
esac
cat "$real"
```

---

## Hardcoded Credentials

**CRITICAL — Credentials in script body**
Passwords, API tokens, access keys, or secrets assigned to variables in the script body:
```bash
# REJECT
PASSWORD="hunter2"
API_KEY="sk-abc123"
curl -H "Authorization: Bearer hardcoded_token_here" ...

# REQUIRE
PASSWORD="${MY_SERVICE_PASSWORD:?env var MY_SERVICE_PASSWORD not set}"
```

**HIGH — Credentials exported to process environment**
`export` statements that expose secret values, which then appear in `/proc/<pid>/environ` and are visible to any process with the same UID.

---

## Insecure Temporary Files

**HIGH — Predictable temp file name**
Temp files with names based on PID (`/tmp/myscript_$$`) or script name are race-condition-exploitable via symlink attacks. PIDs are predictable; an attacker can pre-create the symlink:
```bash
# REJECT
TMP=/tmp/myscript_$$
TMP=/tmp/${0##*/}.tmp

# REQUIRE
TMP=$(mktemp)
TMPDIR=$(mktemp -d)
```

**HIGH — Missing cleanup trap**
Temp files or directories created without a `trap '...' EXIT` to ensure cleanup on all exit paths:
```bash
# REQUIRE
TMP=$(mktemp)
trap 'rm -f "$TMP"' EXIT
TMPDIR=$(mktemp -d)
trap 'rm -rf "$TMPDIR"' EXIT
```

---

## Missing Input Validation

**HIGH — Unvalidated input used in commands**
Scripts that accept positional arguments, read from stdin, or read from environment variables and use them directly in commands without validation:
```bash
# REJECT
process_file() {
    cat "$1"  # $1 could be /etc/passwd, /dev/sda, or contain shell metacharacters
}

# REQUIRE — validate before use
process_file() {
    local file="$1"
    [[ -z "$file" ]] && { echo "file required" >&2; return 1; }
    [[ "$file" =~ ^[a-zA-Z0-9_./-]+$ ]] || { echo "invalid characters in filename" >&2; return 1; }
    [[ -f "$file" ]] || { echo "file not found: $file" >&2; return 1; }
    cat "$file"
}
```

**MEDIUM — Missing length check on user input**
Input used in file names, system calls, or commands without a maximum length check. Extremely long strings can cause unexpected behavior in some tools.

---

## Authoritative References

- ShellCheck wiki: https://www.shellcheck.net/wiki/
- Bash injection prevention: https://mywiki.wooledge.org/BashFAQ/048
- Secure temp files: https://mywiki.wooledge.org/BashFAQ/062
- OWASP Command Injection: https://owasp.org/www-community/attacks/Command_Injection
- Google Shell Style Guide (security sections): https://google.github.io/styleguide/shellguide.html
