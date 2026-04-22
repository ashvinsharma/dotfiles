---
description: Session-scoped edit lock — restrict Write and Edit to a specified directory; Read, Bash, Glob, and Grep remain unrestricted
---

Ask the user: "Which directory should I lock edits to? All Write and Edit operations will be restricted to files within that directory for this session."

Wait for the user to specify a directory path.

Resolve the path to its absolute form (expand `~`, resolve symlinks if needed).

Confirm: "Freeze mode active. Write and Edit are now restricted to: **[absolute path]**. Read, Bash, Glob, and Grep are unrestricted. Say /unfreeze to lift the restriction."

---

## Enforcement

For every subsequent Write or Edit tool call in this session:
- Resolve the target file path to its absolute path
- Check whether it starts with the frozen directory prefix
- If **YES** — proceed normally
- If **NO** — refuse and say:

```
FREEZE MODE: [target file] is outside the locked directory ([frozen path]).
Edit blocked. Use /unfreeze to remove the restriction.
```

Read, Bash (including running tests or builds), Glob, and Grep are not affected by the freeze — only Write and Edit are blocked outside the boundary.

---

## Deactivation

Deactivated when the user says `/unfreeze` or ends the session.

On deactivation: "Freeze mode deactivated. Write and Edit are now unrestricted."
