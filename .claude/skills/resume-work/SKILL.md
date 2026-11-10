---
name: resume-work
description: Resume work on an MR/issue by URL or ref — find its note, worktree and herdr tab; focus the tab if it exists, else recreate it in the worktree and start Claude with --resume <session-id> (or a fresh session told to read the note). With --briefing it is read-only and shows what changed on GitLab since the last checkpoint. /resume-work <url|ref|branch|path>. Named resume-work because /resume is a Claude Code built-in.
argument-hint: "<url | group/project!N | group/project#N | branch | worktree path> [--briefing] [--prompt TEXT] [--focus] [--dry-run]"
allowed-tools: Bash(python3 -I ~/.claude/scripts/wnotes:*), Read
---

# Resume work on an MR/issue

```bash
python3 -I ~/.claude/scripts/wnotes resume $ARGUMENTS            # act: focus or recreate the tab
python3 -I ~/.claude/scripts/wnotes resume $ARGUMENTS --briefing # read-only: what changed since last checkpoint
```

Use `--briefing` when the user asks "what changed", "where was I", or wants context without opening a tab.

## What `resume` does

| State | Result |
|---|---|
| tab exists (label from the index, or an agent whose cwd is inside the worktree) | focus it; with `--prompt` and the agent idle/done, send the prompt; if it is working, only focus |
| tab gone, worktree exists | new tab in the worktree, `claude --permission-mode auto --resume <session-id>` |
| no session id known | fresh session whose first prompt says to read the injected note and continue from "Where I left off" |
| worktree gone | stops: `wnotes start <url>` recreates it |

Session id: live herdr agent → index (set by `/checkpoint`, valid only if its cwd is the worktree) → newest transcript for that cwd. The resumed session's SessionStart hook re-injects the note.

## `--briefing` output

Note path, last checkpoint, worktree cleanliness, tab state, a diff of live MR state against the snapshot taken at the last `/checkpoint` (state, draft, pipeline, unresolved threads, head sha), then the note's Where I left off · Constraints (verbatim) · Open questions · Decisions in force. It writes nothing.

## Rules

- Relay the output tersely; don't re-summarise the note.
- A stale note (merged/closed MR) is flagged, not rewritten — that's `/checkpoint`.
- No match → say so and suggest `/start-work <url>`; never guess between candidates.
