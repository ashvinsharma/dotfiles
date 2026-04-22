---
name: shell-reviewer
description: Shell/Bash script review checklist covering safety, quoting, error handling, POSIX compliance, and shellcheck validation
---

## Mandatory Checks for Shell Scripts

Run this before reviewing:
```bash
shellcheck <script>    # must return zero warnings or errors
bash -n <script>       # syntax check must pass
```

REJECT immediately if `shellcheck` reports any errors or warnings — fix all of them.

## Safety Headers

- REJECT if script is missing `set -euo pipefail` (or equivalent `set -e`, `set -u`, `set -o pipefail`)
- REJECT if shebang is missing or incorrect (`#!/usr/bin/env bash` preferred)

## Quoting

- REJECT if variables are unquoted: `$var` should be `"$var"`
- REJECT if command substitutions are unquoted: `$(cmd)` should be `"$(cmd)"`
- REJECT if word splitting could cause bugs (unquoted variables in loops, conditions)

## Error Handling

- REJECT if errors are silently swallowed (commands run without checking exit code where `set -e` wouldn't catch it)
- REJECT if error messages go to stdout instead of stderr (`>&2`)
- REJECT if temp files are created without a `trap ... EXIT` cleanup

## Functions and Variables

- REJECT if variables inside functions are not declared `local`
- REJECT if global variables are modified inside functions without clear intent
- Flag functions longer than ~30 lines — likely needs splitting

## Portability

- Flag backtick usage — use `$(...)` instead
- Flag `[ ]` where `[[ ]]` is more appropriate (bash scripts)
- Flag `echo` with flags (`echo -e`, `echo -n`) — use `printf` instead for portability

## Authoritative Sources to Cite

- ShellCheck wiki: https://www.shellcheck.net/wiki/
- Google Shell Style Guide: https://google.github.io/styleguide/shellguide.html
- BashFAQ: https://mywiki.wooledge.org/BashFAQ
