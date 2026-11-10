---
name: mr-status
description: Fleet view of all my open GitLab MRs across projects — one status each (draft, blocked, conflicts, requested-changes, red-pipeline, needs-reviewer, waiting-on, pipeline-running, ready), approvals left, threads needing me, whether review was re-requested after my last push, closing issues, the herdr tab handling it, and a suggested action. Read-only; snapshots to a file so a later run shows what changed. Use for "what needs my attention", "status of my MRs", "what changed since last time", or /mr-status.
argument-hint: "[--user <username>] [--no-herdr]"
allowed-tools: Bash(python3 ~/.claude/skills/mr-status/scripts/mr_status.py:*), Bash(glab api:*), Bash(herdr tab list:*), Bash(herdr agent list:*), Read
---

# MR status (fleet view)

One deterministic script does the work. This skill runs it and adds judgment. Read-only: it never posts, resolves, re-requests or pushes.

```bash
python3 ~/.claude/skills/mr-status/scripts/mr_status.py collect          # table + "changed since last run"
python3 ~/.claude/skills/mr-status/scripts/mr_status.py diff             # two newest snapshots only
```

Snapshots: `~/.cache/mr-status/snapshot-*.json` (`--snapshots DIR` to move). `collect` diffs against the newest one automatically.

## Status (first rule wins)

| Status | Rule |
|---|---|
| `draft` | MR is a draft |
| `blocked by !N` | blocks API shows an open blocker, **or** target branch is another open MR's source branch (stacked) |
| `conflicts` | `has_conflicts` |
| `requested-changes by <who>` | reviewers API state (bots incl. GitLabDuo). **Not** the list endpoint's `detailed_merge_status`: it goes stale |
| `red-pipeline (<jobs>)` | head pipeline failed; names the non-`allow_failure` jobs |
| `needs-reviewer` | no human reviewer |
| `waiting-on <who> since <date>` | a human reviewer has not approved (or an approval rule is unmet). Date = my last push / re-request / note |
| `pipeline-running` | head pipeline pending/running |
| `ready` | none of the above |

Threads cell: `N (k new, m nit) +b bot`. `N` = unresolved threads whose last note isn't mine (bots excluded); `new` = non-nit threads updated after my last push; `nit` = marked nit / nitpick / non-blocking.

## Suggested action (the user's rules)

| Situation | Action |
|---|---|
| fix shipped (my push is newer than the reviewer's feedback), review **not** re-requested | `re-request @x` |
| fix shipped **and** re-requested | `close tab <label>` |
| reviewer silent > 3 working days (Mon-Fri, no holidays) | `nudge @x` |
| new non-nit threads since my push | `address N new thread(s)` → `/address-mr-comments` |

Threads that need me never change the **status** (the precedence above is fixed); they show in the Threads cell and the action.

## Report

1. Paste the script's table unchanged (every ref is already a link, dates are absolute).
2. Then the "Changed since" block, if any. Lead with it on a refresh.
3. One line: the single most useful next action. Do not restate the table.
4. Script `Warnings` mean data is incomplete — say so.

Judgment the script cannot make: for `red-pipeline`, flake vs real (a job on a file the MR didn't touch → flake → retry). Suggest, don't retry.

## Herdr tab matching

(1) a herdr agent whose cwd is in the repo and whose branch equals the MR's source branch; (2) tab label with `!<iid>` (e.g. `runner!7775`; project prefix must match); (3) `notes-index.json` if the notes tool provides one. No match → `-`.

## Overlap

`/mr <url>` is the deep single-MR view (what changed, comments, CI, next action). `/mr-status` is the fleet view and never reads diffs. Use `/mr-status` to pick, `/mr` to dig in.

## Testing without touching GitLab

`collect --fixtures DIR` reads `DIR/<rest-api-path>.json` (and `DIR/herdr-tab-list.json`, `herdr-agent-list.json`) instead of calling GitLab/herdr. Always use it with a throwaway fixtures dir when changing the script.
