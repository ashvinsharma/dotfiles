---
name: shell-coder
description: Shell/Bash scripting patterns, safety conventions, POSIX compliance, and error handling for writing robust shell scripts
---

## Script Header (Always)

Every script must start with:
```bash
#!/usr/bin/env bash
set -euo pipefail
```

- `set -e`: exit on error
- `set -u`: exit on undefined variable
- `set -o pipefail`: exit if any command in a pipe fails

## Quoting Rules

- Always double-quote variable expansions: `"$variable"` not `$variable`
- Always double-quote command substitutions: `"$(command)"` not `$(command)`
- Exception: inside `[[ ]]` conditionals, quoting is optional but still good practice
- Use `${var:-default}` for variables that may be unset

## Error Handling

- Check exit codes explicitly when `set -e` won't catch it (e.g., in conditions)
- Use `|| { echo "error message" >&2; exit 1; }` for custom error messages
- Print errors to stderr: `echo "error: something failed" >&2`
- Clean up temp files with `trap 'rm -f "$tmpfile"' EXIT`

## Functions

- Declare local variables with `local`: `local var="value"`
- Functions should do one thing
- Return 0 for success, non-zero for failure

## Portability

- Prefer `[[ ]]` over `[ ]` for conditionals in bash scripts
- Use `$(command)` not backticks for command substitution
- Use `printf` instead of `echo` for reliable output formatting
- Avoid bash-isms if POSIX sh compatibility is required — check the shebang

## Commit Checklist

Before proposing a commit:
1. `shellcheck <script>` returns no warnings or errors
2. Script runs with `bash -n <script>` (syntax check) successfully
3. All variables are quoted
4. `set -euo pipefail` is present
