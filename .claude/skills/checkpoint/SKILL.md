---
name: checkpoint
description: Update the NOTE.md of the current MR/issue (decisions, constraints, open questions, where I left off, session log) and stamp the notes index with live MR state and this session's id. Use at a natural pause, before ending a session, or as hand-back when a herdr agent or subagent finishes work on an MR. /checkpoint [ref|url]; with no argument it uses the note for the current worktree. Pairs with /resume-work and the SessionStart hook that re-injects the note.
argument-hint: "[group/project!N | group/project#N | url]  (empty: note for the current worktree)"
allowed-tools: Bash(python3 -I ~/.claude/scripts/wnotes:*), Bash(python3 ~/.claude/skills/decisions/decisions.py:*), Bash(git status:*), Bash(git log:*), Bash(git branch:*), Read, Edit
---

# Checkpoint the current MR/issue note

Format, paths and index: `~/.claude/skills/checkpoint/FORMAT.md`. This skill never commits and never posts.

Run every `wnotes` / `decisions.py` command as **its own Bash call**, exactly as written. Don't chain with `;` `&&` or add `echo "exit=$?"`: it breaks the allowed-tools prefix match and forces a permission prompt.

## 1. Find the note

```bash
python3 -I ~/.claude/scripts/wnotes lookup "$ARGUMENTS" --path   # with an argument
python3 -I ~/.claude/scripts/wnotes resolve                      # no argument: from cwd
```

No note found → say so, point at `/start-work <url>`, stop. Never create a note by hand.

## 2. Read it, gather state

`Read` the note. Then `git status -sb` and `git log -5 --oneline` in its worktree, plus this conversation.

## 3. Edit in place (`Edit`, never rewrite the file)

| Section | Rule |
|---|---|
| Goal | Only if understanding changed. |
| Merge requests | Sync state; keep merged ones. |
| Decisions in force | Epic ids as `- RJ-D07 · <lead clause>`. A new non-obvious choice: `- <date>: <decision> — <why>`, tag `[epic]` if it binds other MRs. Never delete; a reversal is a new entry. Mechanical fixes get nothing. |
| Constraints from the user | Append only **verbatim quotes** of what the user said this session, dated. Never paraphrase, never infer, never attribute a constraint they did not state. Nothing new → leave untouched. |
| Open questions | Add; strike resolved ones `~~text~~`, never delete. |
| Where I left off | **Overwrite**, 2–5 lines: pushed sha, pipeline, who waits on whom, next action. Absolute dates. |
| Session log | Append under today's `### YYYY-MM-DD` (create it if missing): **always at least one bullet** — one per thread/job: what, commit sha, outcome (nothing happened → "no code changes; checkpointed"). Skip what `git log` or the MR page already show. |

Frontmatter (`last_updated`, `status`) is stamped by step 4. Don't hand-edit it.

## 4. Stamp

```bash
python3 -I ~/.claude/scripts/wnotes stamp --snapshot   # live MR state + session id/tab/cwd + last_updated
python3 -I ~/.claude/scripts/wnotes stamp              # fallback when glab is unavailable
```

Add `--ref <ref>` when checkpointing a note other than the cwd's.

## 5. Check cited decisions (only if the note has an `epic:` iid)

```bash
python3 ~/.claude/skills/decisions/decisions.py check <epic-iid> --file <NOTE.md>
```

Exit 3 → no log, say nothing. Exit 2 → real error, surface it. Pass the **epic iid** only, never an MR/issue URL. A cited id that was reversed → fix the line.

## 6. Confirm

One or two lines: note path, what changed. No dump of the note.

## Hand-back (herdr agents and subagents)

When you finish work on an MR for another agent or the user, run `/checkpoint <ref>` before your final report, then report. Only touch the note of the MR you worked on.
