#!/bin/bash
# SessionStart hook: inject the NOTE.md for the current worktree/branch as context.
# Lookup (worktree path > branch > iid in branch, scoped to the repo's project) is done by
# `wnotes hook` in ONE python3 call: jq via the mise shim alone costs ~180ms.
# Read-only, no network, silent on any failure, always exits 0.
# Invoked as `bash ~/.claude/hooks/resume-from-notes.sh` (the file is not chmod +x).
PY=$(command -v python3) || exit 0
"$PY" -I "$HOME/.claude/scripts/wnotes" hook 2>/dev/null
exit 0
