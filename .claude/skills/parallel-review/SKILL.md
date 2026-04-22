---
name: parallel-review
description: Four specialist reviewer agents run in parallel on every review — Correctness, Coverage, Security (STRIDE), and Dependency Audit — producing a unified REVIEW_STATUS used by both tdd-review-loop and review-and-fix
---

# Parallel Review Protocol

Four specialist agents always run in parallel on every review. All four must approve before the review passes. This protocol is the single review method used by both `tdd-review-loop` and `review-and-fix`.

---

## Setup

Detect languages from file extensions in the diff:
- `.go` → load `go-reviewer` skill in correctness agent; load `go-security` skill in security agent
- `.sh`, `.bash` → load `shell-reviewer` skill; load `shell-security` skill
- `.tf`, `.tofu` → load `tofu-reviewer` skill; load `tofu-security` skill
- Multiple languages → load all matching skills in each agent

Detect dependency manifest files changed in the diff:
- `go.mod`, `go.sum`
- `pyproject.toml`, `requirements*.txt`, `Pipfile`, `poetry.lock`
- `package.json`, `package-lock.json`, `yarn.lock`
- `Gemfile`, `Gemfile.lock`
- `*.tf` (provider version constraints)

Pass detected language(s) and manifest files explicitly when invoking subagents.

---

## Spawn All Four Agents Simultaneously

Do not wait for one before launching the next.

### Agent 1 — Correctness
Invoke the `reviewer` subagent:
> "Focus exclusively on correctness. Check: type safety, nil/None handling, logic errors, unhandled edge cases, idiomatic patterns, error handling, resource leaks. Do NOT review test coverage — that is handled separately. Languages: [list]. Load the matching reviewer skill(s) before reviewing. [diff]"

Parse response for `REVIEW_STATUS:`.

### Agent 2 — Coverage
Invoke the `reviewer` subagent:
> "Focus exclusively on test coverage. Check: every changed code path has a test, error paths are tested, dead code introduced by this diff, tests will fail if the code breaks (not just structural). Do NOT review correctness or style — that is handled separately. Languages: [list]. [diff]"

Parse response for `REVIEW_STATUS:`.

### Agent 3 — Security (STRIDE + input validation)
Invoke the `security-reviewer` subagent:
> "Focus on STRIDE threat modeling, SSRF, input validation, injection vectors, authentication/authorization gaps, information disclosure, and DoS vectors. Do NOT audit dependencies — that is handled separately. Languages: [list]. Load the matching security skill(s) before reviewing. [diff]"

Parse response for `SECURITY_STATUS:`.

### Agent 4 — Dependency Audit (CVE scan)
Invoke the `security-reviewer` subagent:
> "Focus exclusively on dependency security. Scan all changed manifest files for: known-vulnerable version ranges (CVE audit), unpinned versions that could silently upgrade to a vulnerable release, and removed pins that previously constrained a vulnerable range. Manifest files changed in this diff: [list]. Do NOT review application code — that is handled separately. [diff]"

If no manifest files changed, skip this agent and mark it SKIPPED.

Parse response for `SECURITY_STATUS:`.

---

## Outcome Routing

Wait for all agents to return, then evaluate:

- **All agents APPROVED/SECURE** → emit `REVIEW_STATUS: APPROVED`
- **Any agent returns ESCALATE** → emit `REVIEW_STATUS: ESCALATE`
- **Any agent returns REJECTED/ISSUES FOUND** → emit `REVIEW_STATUS: REJECTED` with consolidated issues

The orchestrator emits a single `REVIEW_STATUS:` line consumed by the caller.

---

## Consolidated Issues Format

When any agent rejects, collect all issues into a single block for the coder:

```
CORRECTNESS ISSUES:
[Agent 1 ISSUES block, or "none"]

COVERAGE ISSUES:
[Agent 2 ISSUES block, or "none"]

SECURITY ISSUES:
[Agent 3 ISSUES block, or "none"]

DEPENDENCY ISSUES:
[Agent 4 ISSUES block, or "none — agent skipped"]
```
