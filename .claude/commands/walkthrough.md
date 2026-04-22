---
description: Interactive hunk-by-hunk diff walkthrough — explains each change in context, pauses for questions, notes flagged items, advances only when you say "next"
---

Walk through the current diff one hunk at a time. For each hunk: show it, explain what it does and why it matters, then pause. Advance only when you say "next". Flag anything worth a second look.

---

## Step 1 — Get the diff

Use the staged diff if one exists, otherwise the branch diff against main:
```bash
git diff --cached
# if empty:
git diff main...HEAD
# if on main or no branch diff:
git diff HEAD
```

Split into individual hunks (file path + hunk header + lines).

---

## Step 2 — Hunk walkthrough loop

For each hunk, in order:

### Present the hunk

```
─────────────────────────────────────────────────────
HUNK [N of TOTAL]  [file path]  [hunk header]
─────────────────────────────────────────────────────
[diff lines — additions in green, removals in red]
```

### Explain it

Provide:
1. **What changed** — one sentence describing the mechanical change
2. **Why it matters** — what behaviour or invariant does this affect?
3. **Any flag** — if this hunk has something worth noting (subtle logic change, potential edge case, deleted safety check, etc.), mark it:
   `FLAG: [concern in one sentence]`

### Pause

End every hunk with exactly this line:
```
→ next / ask a question / skip to end
```

Wait for the user's response before showing the next hunk. Do not advance automatically.

---

## Step 3 — Handling responses

- **"next"** (or "n", "continue", "ok") → show next hunk
- **A question** → answer it fully, then re-show the `→ next / ask a question / skip to end` prompt
- **"skip to end"** → show the summary (Step 4) immediately
- **"go back"** → re-show the previous hunk

---

## Step 4 — End-of-diff summary

After the last hunk (or on "skip to end"):

```
WALKTHROUGH COMPLETE
====================
Total hunks: [N]  |  Files changed: [N]

FLAGS RAISED:
- [file:line]: [concern]
(or: None)

OVERALL SHAPE:
[2-3 sentences: what does this diff do as a whole? Is it coherent? Any patterns across hunks worth calling out?]
```

If no flags were raised and the diff is straightforward, say so — don't invent concerns.
