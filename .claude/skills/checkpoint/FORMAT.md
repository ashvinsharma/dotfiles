# Work-note format, index and tools

Tool: `~/.claude/scripts/wnotes` (python3 stdlib; `python3 -I ~/.claude/scripts/wnotes help`).

## Location

```
workflow-artifacts/<org>/workitem-<epic>/<project-slug>/{mr-<iid>|issue-<iid>}/NOTE.md   # epic known
workflow-artifacts/<org>/<project-slug>/{mr-<iid>|issue-<iid>}/NOTE.md                   # no epic
```

`<project-slug>` = project path without the org, `/` → `-` (`gitlab-runner`, `fleeting-taskscaler`).
Epic decisions: `<org>/workitem-<epic>/DECISIONS.md` (see `/decisions`).

## NOTE.md

```markdown
---
kind: mr                       # issue | mr
ref: gitlab-org/gitlab-runner!7643
url: https://gitlab.com/gitlab-org/gitlab-runner/-/merge_requests/7643
title: "..."
epic: 21159                    # iid, or empty
branch: feat/...
worktree: /abs/path
status: opened                 # GitLab state: opened | merged | closed
last_updated: 2026-11-10
aliases: group/project#42      # optional: refs this MR closes → also resolve to this note
---
## Goal · ## Merge requests · ## Decisions in force · ## Constraints from the user (verbatim)
## Open questions (strike, don't delete) · ## Where I left off (overwritten) · ## Session log (dated append)
```

## Index: `workflow-artifacts/notes-index.json`

`{"version":1,"entries":[{ref, kind, project, iid, title, status, url, epic, note, branch, worktree, aliases, tab, session_id, session_cwd, snapshot, updated}]}`
It is a cache of the frontmatter plus volatile fields (tab, session, snapshot): `wnotes reindex` rebuilds it from NOTE.md files.
Writes are locked (fcntl) and atomic (tmp + rename).

## Lookup

| Query | Order |
|---|---|
| `wnotes lookup <q>` | exact ref/url → alias → branch → worktree/note path; bare `!N` / `#N` / `N` use the cwd's repo |
| SessionStart hook / `wnotes resolve` | worktree (the cwd's **git top** equals the entry's worktree; never a path prefix, so a main-checkout entry doesn't claim its nested `.claude/worktrees/*`) → branch (same project) → iid in branch (same project; `issue-N`, `N-slug`, `mr-N`, ≥3-digit token; a hint beats a bare number) |

Notes sharing one worktree/branch (an issue, then its MR) resolve to the branch match, then the newest. Different-kind iid collisions (MR !777 vs issue #777 from a bare number) and anything cross-project inject nothing.

`wnotes stamp` records tab/session/cwd only when the calling herdr pane is inside that note's checkout; run from elsewhere it leaves them alone (`recorded_session: false`). `start` for a fork MR fetches `refs/merge-requests/<iid>/head` when the source branch isn't on origin.

## Tabs and sessions

`wnotes start|resume` create a herdr tab (`herdr tab create --cwd <worktree>`) and `herdr agent start <name> --kind claude --pane <p> -- --permission-mode auto [--resume <id>]`.
Session id for resume: live herdr agent → index `session_id` (written by `start` and `/checkpoint`, only if `session_cwd` equals the worktree) → newest transcript in `~/.claude/projects/<cwd with non-alnum → "-">/`.

## Env

`NOTES_ROOT`, `NOTES_INDEX` override the store (tests use throwaway dirs). They are forwarded to tabs `wnotes` creates.
