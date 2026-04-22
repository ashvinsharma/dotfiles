---
description: Deep code review of a GitLab MR — parallel specialist review (correctness, coverage, security, deps) on the MR diff, with a final VERDICT
---

Given a GitLab MR URL, fetch the diff and run a full parallel specialist review producing a final VERDICT.

Argument: `$ARGUMENTS` — a GitLab MR URL (e.g. `https://gitlab.com/group/project/-/merge_requests/123`)

---

## Step 1 — Fetch the diff

Use the GitLab MCP `get_merge_request_diffs` to fetch all changed files and hunks.

If no URL is provided, check `git branch --show-current` to infer the current branch, find the open MR, then fetch the diff.

---

## Step 2 — Parallel review

Load the `parallel-review` skill. Pass it the full diff and the changed file list. Follow the protocol exactly — it owns language detection, agent setup, and outcome routing, and will produce a single `REVIEW_STATUS:` line.

---

## Step 3 — VERDICT

Map `REVIEW_STATUS` to a verdict:

- `APPROVED` → **VERDICT: APPROVED** — safe to merge
- `REJECTED` → **VERDICT: NEEDS WORK** — list every required fix grouped by agent
- `ESCALATE` → **VERDICT: ESCALATE** — flag for human architect or security expert

---

## Output format

```
MR CODE REVIEW: [MR title]
URL: [url]

SPECIALIST REVIEW
  Correctness : [APPROVED | REJECTED]
  Coverage    : [APPROVED | REJECTED]
  Security    : [APPROVED | REJECTED | ESCALATE]
  Dependencies: [APPROVED | REJECTED | SKIPPED]

CORRECTNESS ISSUES:
  [list or "none"]

COVERAGE ISSUES:
  [list or "none"]

SECURITY ISSUES:
  [list or "none"]

DEPENDENCY ISSUES:
  [list or "none / skipped"]

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
VERDICT: [APPROVED | NEEDS WORK | ESCALATE]
[One paragraph summary. If NEEDS WORK, list every required fix.]
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

---

## Critical rules

1. Always run `parallel-review` — never inline the agent prompts here
2. Pass the full diff to the skill — do not summarise or truncate it
3. No auto-fix loop — this command is read-only; fixes are the MR author's responsibility
