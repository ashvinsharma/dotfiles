---
description: Maximum safety mode — activates careful (destructive command confirmation) and freeze (edit lock) together in one command
---

Activating guard mode — maximum safety for production-adjacent work.

**Step 1 — Careful mode:** All destructive bash commands (rm, DROP, reset --hard, push --force, destroy, kubectl delete, etc.) will require explicit confirmation before execution. Whitelisted targets (node_modules, dist, /tmp, build artifacts) are auto-approved.

**Step 2 — Freeze mode:** Ask the user: "Which directory should I lock edits to? Write and Edit will be restricted to that directory for this session."

Wait for the user to specify a directory, resolve it to an absolute path, then confirm:

"Guard mode active.
- Careful: destructive commands require confirmation
- Freeze: Write and Edit restricted to **[absolute path]**

To lift the edit lock: say /unfreeze. Careful mode clears at session end."
