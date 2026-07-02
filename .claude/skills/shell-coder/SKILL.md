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
- **`VAR=$(failing_cmd)` never triggers `set -e`** — the assignment itself exits 0 regardless of the subshell's exit code; `VAR` is set to empty/stdout and execution continues silently. Guard explicitly:

```bash
# Bad: set -e does NOT fire here even if some_command fails
OUTPUT=$(some_command)

# Good: guard the result
OUTPUT=$(some_command)
[ -n "$OUTPUT" ] || { echo "some_command produced no output" >&2; exit 1; }

# Or capture exit code directly
if ! OUTPUT=$(some_command); then
    echo "some_command failed" >&2
    exit 1
fi
```

## Functions

- Declare local variables with `local`: `local var="value"`
- Functions should do one thing
- Return 0 for success, non-zero for failure

## Portability

- Prefer `[[ ]]` over `[ ]` for conditionals in bash scripts
- Use `$(command)` not backticks for command substitution
- Use `printf` instead of `echo` for reliable output formatting
- Avoid bash-isms if POSIX sh compatibility is required — check the shebang

## Git: always commit shell scripts with executable bit

Shell scripts committed without `+x` will fail with "Permission denied" after
`git reset --hard` or a fresh clone — git restores the mode it stored, not what
was set manually with `chmod`.

Always set the executable bit in the index before committing:

```bash
git update-index --chmod=+x path/to/script.sh
```

Verify before committing:
```bash
git ls-files --stage path/to/script.sh   # must show 100755, not 100644
```

This applies to every shell script, git hook, and any other executable file
added to the repo — including files without a `.sh` extension (e.g.
`reference-transaction`, `post-commit`).

**`git add` reads permissions from disk, not from the index.** Write and Edit
tools create/modify files at 644 on disk. If you run `git update-index --chmod=+x`
but then run `git add` again on the same file, git overwrites the index entry
with the disk's 644. Always run `git update-index --chmod=+x` AFTER any
`git add`, immediately before committing.

## Commit Checklist

Before proposing a commit:
1. `shellcheck <script>` returns no warnings or errors
2. Script runs with `bash -n <script>` (syntax check) successfully
3. All variables are quoted
4. `set -euo pipefail` is present
5. Executable bit set in git index (`git ls-files --stage` shows `100755`)
