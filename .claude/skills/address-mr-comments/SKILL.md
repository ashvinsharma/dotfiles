---
name: address-mr-comments
description: Address unresolved review threads on one or more of my GitLab MRs with one background agent per MR — classify each thread (blocking / should-fix / nit / question), check the epic's decision log, make a minimal fix with one commit per thread and the package tests, draft replies only where a reply is warranted, and stop. After the user's ok it pushes, posts the replies and re-requests review from the human reviewers. Never resolves others' threads. Use "--dry-run" to draft without edits or commits. /address-mr-comments [--dry-run] <mr-url | group/project!N | iid>...
argument-hint: "[--dry-run] <mr-url | group/project!N>..."
allowed-tools: Bash(python3 ~/.claude/skills/address-mr-comments/scripts/mr_threads.py list:*), Agent, SendMessage, ToolSearch, Read, Edit
---

# Address MR comments

This session briefs agents, shows the drafts, waits for the user's ok and relays results. **It never fixes, pushes or posts itself.**

```bash
python3 ~/.claude/skills/address-mr-comments/scripts/mr_threads.py list --project <group/project> --iid <N>   # read-only peek
```

No unresolved threads → say so, stop.

## Flow

1. **Peek**: run `list` per MR (read-only) for the thread count and worktree. No worktree → tell the user, skip that MR.
2. **Spawn** one background `general-purpose` agent per MR, all in one message (parallel). Prompt:

   > Address review threads on `<project>!<iid>` in mode `<dry-run|normal>`. Read
   > `~/.claude/skills/address-mr-comments/agent.md` and follow it. Stop after the draft file. Return its path, one
   > line per thread, and anything needing the user's decision.

   Add only facts the agent cannot find itself. Do not add your view of what the threads want.
3. **Review**: when an agent returns, show its draft (the file content, not a paraphrase). Offer
   `/plannotator-annotate <draft>` for line-level edits. Threads flagged "needs decision" → ask the user.
4. **Ok** (normal mode only): when — and only when — the user says ok, stamp the draft and continue the agent:

   ```bash
   # Edit the draft front matter:  approved:  ->  approved: 2026-11-10T14:05
   ```
   `SendMessage` is a deferred tool: load it first (`ToolSearch` with `select:SendMessage`), then continue the agent
   with "ok — push, post, re-request". Edits the user made to the draft are the source of truth.
5. **Relay**: pushed sha, posted note ids, re-requested users, threads left open. Suggest `/mr-status` to see the new state.

## The user's ok covers

That MR only: one normal push of its branch, the replies in the draft, re-request from the listed human reviewers.
Not covered: force-push/rebase (ask separately; `--force-with-lease`), resolving threads, other MRs.

## Rules (from the user)

- Never post, push or re-request without the ok. Never resolve other people's threads unless the user says so.
- Do not reply to every comment. Skip nits. A shipped fix = commit + re-request, no "Fixed" reply.
- Already-decided points: cite the decision id, don't re-argue (`/decisions`). MR → epic first; the CLI takes epics only.
- MRs carry logic only: no generated files, no `.gitignore`/lint-config edits. The pre-push scope hook enforces this; the agent never sets its override.
- Commits follow `gitlab-commit-guideline` + the repo's AGENTS.md.

## Dry run

`/address-mr-comments --dry-run <mr>`: the agent classifies, checks decisions, writes the *planned* fix per thread and the draft replies. No edits, commits, push or post. Safe on any MR.

## Testing without GitLab

`mr_threads.py list --project 1 --iid 7 --fixtures <dir>` (fixture layout: see `mr-status`). `reply` / `rerequest` print the call unless `--execute`, which is refused with `--fixtures`, and without the draft's `approved:` stamp.
