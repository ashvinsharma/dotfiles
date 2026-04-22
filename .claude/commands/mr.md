---
description: MR merge-readiness review — what changed, outstanding comments to address, CI status, and your next action to get it merged
---

Given a GitLab MR URL, produce a merge-readiness summary: what changed, what comments need addressing, CI status, and the single next action to get it merged.

Argument: `$ARGUMENTS` — a GitLab MR URL (e.g. `https://gitlab.com/group/project/-/merge_requests/123`)

---

## Step 1 — Fetch MR data

Use the GitLab MCP to fetch:
- MR metadata: title, description, state, author, assignees, reviewers, merge status, target branch
- Diff: changed files and hunks
- Discussions/notes: all threads (resolved and unresolved), inline comments
- CI/pipeline: latest pipeline status and any failing jobs

If no URL is provided, check `git log --oneline -1` and `git branch --show-current` to infer the current MR, then fetch it.

---

## Step 2 — Summarize what changed

In 2-5 sentences: what problem does this MR solve, and how? Mention the key files or systems touched. Do not list every file — give the architectural change.

---

## Step 3 — Outstanding items

List every unresolved thread grouped by category:

**Blocking (requested changes or open questions from reviewers):**
- [thread author] at [file:line]: [one-sentence summary of what they're asking]

**Non-blocking (suggestions, nits, FYI comments):**
- [thread author] at [file:line]: [one-sentence summary]

If all threads are resolved, write: "No outstanding comments."

---

## Step 4 — CI status

One line per failing job:
- [job name]: [failure reason if available in logs]

If CI is passing, write: "CI: passing."

---

## Step 5 — Next action

One sentence. Be specific: name the file, thread, or person. Examples:
- "Address the 3 unresolved threads from @alice before requesting re-review."
- "Fix the failing `unit-tests` job — see test output above."
- "All comments resolved and CI green — request final approval from @bob."

---

## Output format

```
MR REVIEW: [MR title]
URL: [url]
State: [open | merged | closed]  |  Target: [branch]  |  CI: [passing | failing | pending]

WHAT CHANGED
[2-5 sentence summary]

OUTSTANDING COMMENTS ([N] blocking, [N] non-blocking)
Blocking:
  - [author] at [file:line]: [summary]

Non-blocking:
  - [author] at [file:line]: [summary]

CI STATUS
  [job]: [status / reason]

NEXT ACTION
[One specific, actionable sentence]
```
