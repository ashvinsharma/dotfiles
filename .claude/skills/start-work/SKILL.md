---
name: start-work
description: Start working on a GitLab issue or MR — create/reuse its worktree, scaffold NOTE.md, register it in the notes index, and open a herdr tab running a Claude agent in auto mode. Use when beginning work from an issue/MR URL; /start-work <url|group/project!N|group/project#N>. Does NOT self-assign or change issue status (that would post to GitLab): it prints the glab commands instead.
argument-hint: "<issue/MR url | group/project!N | group/project#N> [--epic N] [--no-agent] [--repo-dir D] [--prompt TEXT] [--dry-run]"
allowed-tools: Bash(python3 -I ~/.claude/scripts/wnotes:*), Read
---

# Start work on an issue or MR

```bash
python3 -I ~/.claude/scripts/wnotes start $ARGUMENTS
```

What it does (all deterministic, no model work):

| Target | Worktree | Branch |
|---|---|---|
| issue | `<repo>/.claude/worktrees/<iid>-<slug>` | new `issue-<iid>-<slug>` off `origin/HEAD` |
| MR | `.claude/worktrees/<source-branch, / → ->` (or the worktree already holding the branch) | the MR's source branch |

Then: scaffold `NOTE.md` if absent (never overwritten) → add/update the index entry → herdr tab (label `runner!7643` / `runner#39603`) with `claude --permission-mode auto` (answers an oh-my-zsh update prompt with `n`). The SessionStart hook injects the note into the new agent.

Metadata comes from `glab api`; the repo is `~/workspace/<project path>` unless `--repo-dir` says otherwise.

## After it runs

1. Relay its output (worktree, note, tab, session).
2. For an issue it prints the `glab issue update … --assignee` command and the status hint — **show them, do not run them**.
3. Stop. Don't implement, push or open an MR.

## Flags

- `--epic N` — epic iid when GitLab didn't report one; puts the note under `workitem-N/`. Check the printed note path.
- `--no-agent` — everything except the tab (use when you are already in the right tab).
- `--prompt TEXT` — first prompt for the new agent (default: none).
- `--dry-run` — print the plan, change nothing.
- `--branch`, `--base`, `--worktree-dir`, `--no-fetch`, `--focus`, `--label`.

## Failure modes

- `no local checkout at …` → rerun with `--repo-dir <path>`.
- `… has origin X, expected Y` → wrong checkout; fix `--repo-dir` (`--force-repo` only if the remote is a fork).
- Fork/community MR (`source_project_id` ≠ `target_project_id`, or the branch isn't on origin): the branch is fetched from `refs/merge-requests/<iid>/head` — a snapshot with no push target.
- A brand-new directory makes Claude show its folder-trust dialog: `start` reports "blocked", keeps note+index, and never answers it for you — answer it in the tab.
- Re-running is safe: worktree and note are reused, an existing tab is reused.
- Epics have no NOTE.md (`<org>/workitem-<iid>/DECISIONS.md` only).
