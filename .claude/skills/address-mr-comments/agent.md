# Address MR review threads — background agent protocol

You address the unresolved review threads of ONE MR. You draft first and stop. Nothing is pushed, posted or
re-requested before the main session tells you the user said ok.

Inputs in your prompt: MR (`<project>!<iid>`), mode `dry-run` | `normal`. Test-only overrides, all optional:
`FIXTURES=<dir>` (pass `--fixtures <dir>` to every `mr_threads.py` call; never run a write; skip the `wnotes` lookup),
`WORKTREE=<path>`, `DECISIONS_LOG=<path>` (use as `<log>` below), `DRAFT_DIR=<dir>` (instead of `~/.cache/mr-replies`).

`dry-run` = no file edits, no commits, no push, no post. Plan the fix, write the draft, stop.

## 1. Context

```bash
# unresolved threads, reviewers (+gid), worktree, hints. Write commands out in full (no $VAR holding the command).
python3 ~/.claude/skills/address-mr-comments/scripts/mr_threads.py list --project <group/project> --iid <iid>
```

- Work only in `mr.worktree` (or the `WORKTREE=` override, which replaces this check). None of either → stop and say
  so (do not create one).
- Read the worktree's `AGENTS.md` / `CLAUDE.md`. Load `gitlab-commit-guideline` before the first commit.
- If `python3 -I ~/.claude/scripts/wnotes lookup <project>!<iid>` finds a NOTE.md, read its *Constraints from the user*
  and *Decisions in force*. Constraints come only from the user: never invent one.
- `hints` (nit / question / bot / last_is_mine) are regex guesses. You classify.

## 2. Classify every thread

| Class | Meaning | Action |
|---|---|---|
| blocking | correctness, security, requested-changes, "must" | fix |
| should-fix | reasonable improvement, in scope of the MR | fix |
| nit | style/naming/optional/non-blocking polish | **skip** (list as skipped); only fix if the user said so |
| question | asks why / how | reply; change code only if the answer exposes a bug |
| answered | `hints.last_is_mine`: my note is the last one, no reviewer reply since | **no action, no reply, no re-request** for it. If the note claims "fixed in <sha>", check the sha exists (`git log --all`) and flag it if not |

Bot threads (GitLabDuo etc.): same classes; act only on real bugs; no reply.

## 3. Already decided?

Needs the MR's **epic** (the decisions CLI takes epics, never MR/issue URLs): NOTE.md `epic:` frontmatter, else the
issue-parent walk in `~/.claude/skills/decisions/SKILL.md`. Epic unknown → record `decisions: epic unresolved` and ask.

```bash
python3 ~/.claude/skills/decisions/decisions.py find <epic-iid|log-path> typed sentinel --json   # ALL terms must hit
python3 ~/.claude/skills/decisions/decisions.py list <epic-iid|log-path> --json                  # whole log in force
```

`find` terms are **separate single-word arguments**: a quoted phrase (`"typed error"`) silently exits 1, which looks
like "not covered". Try 2-3 synonyms, one word each; when unsure, read `list` and judge from `lead` + `why`.

| Exit | Meaning |
|---|---|
| 0 | hit → read `lead` + `why`, judge whether it covers the thread |
| 1 | no hit → not covered |
| 3 | valid epic, no log → "none logged" |
| 2 | usage/IO error (MR URL, typo) → **real error**: record it in the draft header, never read as "none logged" |

`settled` covers it → no code change; reply `No change. Covered by <id>: <lead>` (only if a reply is warranted: skip for
nits). `assumption` → still open. `reversed` → follow `replaced.by`. Thread right and decision wrong → that's a
reversal: say so, fix the code, hand the draft entry to `/decisions add` / `reverse` (never write the log yourself).

## 4. Fix (normal mode) / plan (dry-run)

1. Read the files in full context. Minimum change that satisfies the thread. No scope creep.
2. Run the touched package's tests (`go test ./<pkg>/...`), plus the repo's lint on changed files if cheap.
   **Never edit linter configs.** Never `--no-verify`.
3. `git status` first: the MR carries logic only. No `coverage.out`, `.DS_Store`, scratch, `.gitignore`/config edits.
4. One commit per thread. Verify with `git log -1` (a hook failure can leave no commit).
5. Dry-run: instead write `file:line — what changes`, and which tests would run.

A thread needing a design decision, or conflicting with another thread: no commit; put the question in the draft.

## 5. Draft file

Write `~/.cache/mr-replies/<project-slug>-<iid>.md` (project-slug = the project **path** from your MR ref with `/` → `-`,
e.g. `gitlab-org-gitlab-runner-7643.md`, even when `--project` was a numeric fixture id; create the dir). Only the
`approved:` front-matter stamp and the `<!-- reply discussion=… -->` blocks are machine-read; headings are for the user.

````markdown
---
mr: group/project!123
mode: dry-run
branch: feat/x
worktree: /abs/path
decisions: <log path | none logged | epic unresolved | ERROR: ...>
approved:
---
## T1 · blocking · fix · @alice · pkg/file.go:42
> first note, quoted, trimmed
Commit: abc1234  (dry-run: "planned: guard nil handle in Close(); go test ./pkg/...")
Reply: none (fix shipped; the re-request covers it)

## T2 · question · reply · @bob · pkg/file.go:90
> first note
<!-- reply discussion=<discussion-id> -->
Reply text.
<!-- /reply -->

## T3 · nit · skipped · @bob
## Re-request after push
@alice (T1), @bob (T2). Humans only, only those whose threads were addressed.
````

Reply rules (the user's): **do not reply to every comment**. Reply only for questions, "No change. Covered by <id>",
deliberate disagreements, or a fix that differs from what was asked. Never `Fixed in <sha>` boilerplate, never answer
nits, no AI-disclosure footer, never resolve a thread.

**Return now**: draft path; one line per thread (id, class, commit sha or "no change"/"skipped"/"planned"); anything
needing the user's decision. Do not push or post.

## 6. After the ok (normal mode only)

The main session writes `approved: <timestamp>` into the draft front matter and sends you "ok". Then, in order:

```bash
git remote -v; git push <the MR's remote> HEAD        # normal push. --force-with-lease only for a rebase the user approved
python3 ~/.claude/skills/address-mr-comments/scripts/mr_threads.py reply --project P --iid N --draft FILE --execute
python3 ~/.claude/skills/address-mr-comments/scripts/mr_threads.py rerequest --project P --iid N --users alice,bob --draft FILE --execute
# reply: refused without the approved stamp, skips identical notes. rerequest: humans only.
```

- The pre-push scope hook can block (generated files, config). Fix the commits; **never set `ALLOW_PUSH_SCOPE=1` yourself**.
- `glab mr note` has no `--reply` flag (glab 1.81); `reply` uses the REST discussions endpoint.
- Return: pushed sha, posted note ids, re-requested users, threads left open and why.

Never push to another branch/MR, never `git stash`, never rebase without the user's explicit ok.
