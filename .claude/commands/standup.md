---
description: Daily standup prep — recent commits, open GitLab todos, upcoming meetings, draft answers to yesterday/today/blockers
---

Compile a standup draft from git history, GitLab todos, and calendar. Output a ready-to-use standup. Do not post or send anything without explicit confirmation.

---

## Step 1 — What did I do yesterday?

Check git log for commits in the last 24 hours (or since last working day if today is Monday):
```bash
git log --oneline --since="1 day ago" --author="$(git config user.email)"
```

If in a multi-repo workspace, check all repos under `~/workspace/`:
```bash
find ~/workspace -maxdepth 3 -name ".git" -type d | sed 's/\/.git$//' | while read repo; do
  commits=$(git -C "$repo" log --oneline --since="1 day ago" --author="$(git config -C "$repo" user.email)" 2>/dev/null)
  [ -n "$commits" ] && echo "=== $repo ===" && echo "$commits"
done
```

Summarize commits into work items (group related commits, drop noise like "wip" or "fix typo").

---

## Step 2 — What am I doing today?

Check GitLab todos via MCP:
- Open todos assigned to me
- MRs with requested changes that need addressing
- Open MRs waiting for my review

Check Glean for today's calendar events (meetings that might affect availability):
```
mcp__glean__meeting_lookup: today
```

Infer today's plan from:
1. Yesterday's commits — what was in progress?
2. Open todos — what is outstanding?
3. Any meetings that need prep?

---

## Step 3 — Any blockers?

Scan for signals of being blocked:
- MRs with unresolved blocking comments (no activity in >24h)
- CI failures with no fix committed
- Open questions in GitLab threads with no response

List only real blockers — things that prevent you from making progress today.

---

## Step 4 — Draft the standup

```
STANDUP — [date]
=================

YESTERDAY
- [work item 1]
- [work item 2]

TODAY
- [planned work 1]
- [planned work 2]

BLOCKERS
- [blocker] / None
```

Keep each item to one line. Use plain language, not commit messages. Drop WIP details.

---

## Step 5 — Confirm before any action

If the user asks to post this to Slack, a GitLab issue, or any external system: show the draft first and ask "Post this to [destination]? (yes/no)" — do not send without an explicit "yes".
