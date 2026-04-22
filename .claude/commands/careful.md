---
description: Session-scoped safety guard — require explicit confirmation before any destructive bash command, with auto-whitelist for known-safe targets
---

Careful mode is now active for this session.

Before executing any bash command that matches the destructive patterns below, you must:
1. State the exact command
2. Describe in plain English what it will permanently delete, destroy, or modify
3. Name the specific target (file, table, branch, resource, pod, etc.)
4. Wait for an explicit "yes" from the user before proceeding

Any response other than a clear "yes", "yes I'm sure", or "force" means **abort** — say "Command aborted." and do not execute.

---

## Destructive Patterns (require confirmation)

**Filesystem**
- `rm -rf`, `rm -r`, `rm -f` — any target not on the whitelist below

**Database**
- `DROP TABLE`, `DROP DATABASE`, `DROP SCHEMA`
- `TRUNCATE` (any table)
- `DELETE FROM` without a `WHERE` clause

**Git**
- `git reset --hard`
- `git push --force`, `git push -f`
- `git checkout --` (discards working tree changes)
- `git restore` (discards working tree changes)
- `git clean -f`, `git clean -fd`, `git clean -fdx`, `git clean -fx`

**Kubernetes**
- `kubectl delete` (any resource type)

**Docker**
- `docker system prune`
- `docker volume prune`
- `docker image prune`
- `docker container prune`

**Infrastructure**
- `tofu destroy`, `terraform destroy`
- Any IaC `destroy` or `delete` command

---

## Whitelist (auto-approved, no confirmation needed)

These targets are safe to delete without confirmation:
- Paths under `node_modules/`, `.next/`, `dist/`, `build/`, `bin/`, `target/`, `__pycache__/`, `.cache/`, `.tmp/`
- Paths under `/tmp/` or `$TMPDIR`
- `vendor/` directories
- Files matching `*.pyc`, `*.class`, `*.o`, `*.a` (compiled artifacts)

---

## Confirmation Protocol

When a destructive command is detected:

```
CAREFUL MODE: Destructive command detected.
Command:  [exact command]
Effect:   [plain English — what gets permanently deleted/destroyed]
Target:   [specific file, table, branch, resource, pod, etc.]

This cannot be undone. Proceed? (yes/no)
```

---

## Override

If the user says "yes", "yes I'm sure", "force", or "I know what I'm doing" — execute that one command without further confirmation. Careful mode remains active for all subsequent commands in this session.
