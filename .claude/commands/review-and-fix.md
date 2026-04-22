---
description: Pre-PR quality gate — runs parallel specialist reviewers (correctness, coverage, security, dependency-audit) on the full branch diff, auto-fixes issues via coder agent, produces PASS/FAIL/ESCALATE report
---

Run a quality gate on the current branch before it goes to a PR.

---

## Step 1 — Get the diff

Determine the base branch:
```bash
git rev-parse --verify main 2>/dev/null && echo main || echo master
```

Get the full diff and changed file list:
```bash
git diff main...HEAD
git diff main...HEAD --name-only
```

---

## Step 2 — Parallel review

Load the `parallel-review` skill. Pass it the full diff, the changed file list, and any changed dependency manifests. Follow the protocol exactly — it owns language detection, agent setup, and outcome routing, and will produce a single `REVIEW_STATUS:` line.

---

## Step 3 — Act on REVIEW_STATUS

**`REVIEW_STATUS: APPROVED`** → go to Step 4 (report) with PASS.

**`REVIEW_STATUS: ESCALATE`** → invoke the `architect` subagent with the full diff and all agent responses. After the architect decides, continue to Step 4.

**`REVIEW_STATUS: REJECTED`** → enter the fix loop:

Collect all issues from every agent that did not approve and pass them to the `coder` subagent in a single call:

```
Fix the following issues found across specialist reviewers. Address all of them in this pass.

CORRECTNESS ISSUES:
[Agent 1 ISSUES block, or "none"]

COVERAGE ISSUES:
[Agent 2 ISSUES block, or "none"]

SECURITY ISSUES:
[Agent 3 ISSUES block, or "none"]

DEPENDENCY ISSUES:
[Agent 4 ISSUES block, or "none"]
```

After coder responds, re-run `git diff main...HEAD` and re-run the full `parallel-review` protocol with the updated diff.

**Iteration cap:**
- Correctness + Coverage agents: max 3 iterations
- Security + Dependency agents: max 2 iterations

If any agent is still failing at its cap, invoke the `architect` subagent:
```
ESCALATION: REJECTION_LOOP ([N] iterations)
DIFF: [current diff]
AGENT: [which agent(s) failed]
REVIEW HISTORY: [all feedback across iterations]
```
After architect responds, do one final re-run of all four agents.

---

## Step 4 — Report

```
REVIEW-AND-FIX REPORT
=====================
Branch:     [branch name]
Base:       [main | master]
Languages:  [detected list]
Manifests:  [detected list, or "none changed"]

Correctness:       [PASSED (N round(s)) | ESCALATED | FAILED]
Coverage:          [PASSED (N round(s)) | ESCALATED | FAILED]
Security (STRIDE): [PASSED (N round(s)) | ESCALATED | FAILED]
Dependency Audit:  [PASSED (N round(s)) | ESCALATED | FAILED | SKIPPED]

[If any issues remain unresolved:]
OUTSTANDING ISSUES:
- [agent]: [description]

[If any language lacked a dedicated skill:]
SKILL GAPS:
- [language]: no dedicated reviewer/security skill — generic knowledge used

FINAL_STATUS: [PASS | FAIL | ESCALATE]
```

---

## Critical rules

1. Always run `parallel-review` — never inline the agent prompts here
2. Re-run `git diff main...HEAD` before each fix-loop iteration
3. Collect ALL agent failures before invoking coder — one coder call per iteration, not one per agent
4. The report must always end with `FINAL_STATUS:` — this line is parsed by callers
