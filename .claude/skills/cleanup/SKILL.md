---
name: cleanup
description: Feedback loop for finished work — for my MRs merged since the last confirmed run, read the human/Danger/Duo review threads plus the Claude sessions behind them, distill actionable generalizable rules, route them (repo AGENTS.md / workstream decision log / personal CLAUDE.md), then (after ok) mark notes merged, prune merged worktrees and close finished herdr tabs. Proposes everything first; never commits, pushes or posts. Also `worktrees` and `layout` audits. Use at the end of a work stretch or weekly, or /cleanup.
argument-hint: "[--dry-run] [worktrees | layout] [--since ISO] [--mr group/project!iid]"
allowed-tools: Bash(bash ~/.claude/skills/cleanup/bin/cleanup-mrs:*), Bash(bash ~/.claude/skills/cleanup/bin/cleanup-threads:*), Bash(bash ~/.claude/skills/cleanup/bin/cleanup-digest:*), Bash(bash ~/.claude/skills/cleanup/bin/cleanup-issue-state:*), Bash(bash ~/.claude/skills/cleanup/bin/worktree-audit:*), Bash(bash ~/.claude/skills/cleanup/bin/layout-audit:*), Bash(bash ~/.claude/skills/cleanup/bin/cleanup-note find:*), Bash(bash ~/.claude/skills/cleanup/bin/cleanup-state get:*), Bash(python3 ~/.claude/scripts/wnotes lookup:*), Bash(date -u:*), Read, Glob, Grep, Agent
---

# /cleanup

`$B` = `bash ~/.claude/skills/cleanup/bin` — type it out in full (no shell variable; no `+x` needed).
The scripts are GET-only by construction (`glab api` without `-X`). Nothing here commits, pushes or posts to GitLab.
Writers (`cleanup-note status`, `cleanup-state confirm`, `wnotes add`, `bash <proposed>.sh`, `herdr tab close`) are deliberately **not** pre-approved: each prompts, and each needs the user's ok first.

| Arg | Does |
|---|---|
| *(none)* | Steps 0-7 below |
| `--dry-run` | Steps 0-4 only: print candidates and proposed rules, change nothing, **do not** `confirm` |
| `worktrees` | Step 6 only (audit + proposal) |
| `layout` | Layout audit only (see end) — never part of the default run |

## 0 · Start

```bash
date -u +%Y-%m-%dT%H:%M:%SZ        # remember as RUN_START (confirmed in step 7)
```

## 1 · Candidates

```bash
bash ~/.claude/skills/cleanup/bin/cleanup-mrs [--since ISO] [--mr group/project!iid]
```

TSV: `merged_at  project  iid  branch  title  url`. Default window = last confirmed run (else 21 days).
Empty → say "nothing merged since <ts>" and stop.

## 2 · Gather (per MR — fan out read-only agents when there are more than ~3)

```bash
bash ~/.claude/skills/cleanup/bin/cleanup-threads <project> <iid>
bash ~/.claude/skills/cleanup/bin/cleanup-digest  <project> <iid> --repo ~/workspace/<project>
```

- `cleanup-threads`: non-system threads, **human** → **bot** (Danger) → **duo** (GitLabDuo, lower signal: say so, never rule on Duo alone).
- `cleanup-digest`: human prompts (`⚠` = user correction, `⛔` = interrupt), rejected tool calls, failed calls, commands run 3+ times.
- Series (`1/4`, `2/4` …): gather all, **dedupe rules across the series**.
- Skip nits, bot noise, one-off typos, network/permission blips.

## 3 · Distill

A rule is **do X instead of Y**, generalizable, with one evidence pointer (MR thread / session prompt). Not "what went wrong".

```
✗ "coverage.out was pushed in !123"
✓ "Before every push: git diff --stat origin/main...HEAD; drop generated files (coverage.out…). MRs carry only logic changes."   (evidence: !123 thread, session ⚠ prompt)
```

- User **corrections (`⚠`) and rejected tool calls are the strongest evidence** for personal-workflow rules.
- Constraints come only from the user. A rule may not attribute an invented constraint to them.
- `grep` the target (`AGENTS.md`, `CLAUDE.md`, `.claude/rules/`, decision log) first; skip restatements, add a pointer instead.
- Nothing generalizable for an MR → write nothing for it.

## 4 · Route and present (then STOP for ok)

| Rule is about | Route | Form |
|---|---|---|
| a repo's code / review conventions | that **MR's own repo**: `AGENTS.md` → "Patterns from past fixes" (Rails MRs → the `gitlab` repo's, not runner's), or a `.claude/rules/<topic>.md` with `paths:` frontmatter (**copy**, never a symlink — rules aren't loaded through symlinks) | unified diff, **not applied** |
| one workstream (contract, rollout order, gating) | `/decisions add` for that epic's log; a lead clause + why + `([!N](url))`. Inferred → `--section assumptions` | the exact `--text` line |
| how I work with agents | `~/.claude/CLAUDE.md` or a skill; follow CLAUDE.md → *Continuous Learning*: announce which file and why **before** touching it | diff, **not applied** |

Present one table: `# · rule · route · evidence`. Then ask which to apply. `--dry-run` ends here.
Offer `/artifact` to save the proposal.

## 5 · Apply what was approved

- Rule edits: apply only the approved diffs, in the working tree. **Never commit** — offer to.
- `/decisions add`: run its draft → dry-run → ok flow per entry.

## 6 · Close the loop (each sub-step needs its own ok)

```bash
python3 ~/.claude/scripts/wnotes lookup '<project>!<iid>' --path          # the note, via the notes index
bash ~/.claude/skills/cleanup/bin/cleanup-note find '<project>!<iid>'     # fallback: matches frontmatter ref:, never the dir name
bash ~/.claude/skills/cleanup/bin/cleanup-note status <NOTE.md> merged    # frontmatter status + last_updated
python3 ~/.claude/scripts/wnotes add --ref '<project>!<iid>' --status merged   # sync ONLY status in the index (keeps tab/session_id)
bash ~/.claude/skills/cleanup/bin/cleanup-issue-state <project> <n>       # closed → same for the issue note: ref '<project>#<n>', status closed
```

Do **not** use `wnotes stamp` (it overwrites the note's recorded session/tab with this session's) or `wnotes reindex` (global rewrite).
No NOTE.md for an MR → skip silently.

```bash
bash ~/.claude/skills/cleanup/bin/worktree-audit --tabs --script <scratchpad>/worktrees.sh
```

Show the table and the **⚠ Needs your attention** list verbatim (dirty / local-only / heuristic / in-artifacts are never removed).
With ok, `bash <scratchpad>/worktrees.sh` (only `git worktree remove` without `--force`, and `git worktree prune`).
Tabs: `herdr tab close <id>` only for the ones the audit listed, and only after ok. The audit matches tabs by exact label (`<worktree dir>` or `…!<iid>`) and never lists a tab that also belongs to an active, dirty or unresolved worktree.

## 7 · Confirm

Only after steps 4-6 finished with the user's answers (partial approval counts; an aborted or `--dry-run` run does not):

```bash
bash ~/.claude/skills/cleanup/bin/cleanup-state confirm <RUN_START>
```

End with a ❌ list of anything declined, failed or left for the user.

## `layout` (only when asked)

```bash
bash ~/.claude/skills/cleanup/bin/layout-audit --script <scratchpad>/layout.sh [--resolve] [--exclude 'glob']
```

Report + proposal; **never run** the script without the user reading it. Canonical layout = `~/.claude/commands/artifact.md`
(the README is older and is reported as a gap). Ambiguous items (bare numbers, MRs without a parent epic) are listed, never moved.
Exclude in-flight dirs (`--exclude 'workflow-artifacts/general/<today-slug>/*'`).

## Scripts (`bin/`, all read-only except `cleanup-state confirm` and `cleanup-note status`)

| Script | Purpose |
|---|---|
| `cleanup-mrs` | merged MRs since last confirm / `--since` / `--mr` |
| `cleanup-threads` | discussion threads grouped human/bot/duo |
| `cleanup-digest` | session digest by branch (`gitBranch` grep + worktree dir; spans of other branches filtered) |
| `cleanup-note` | `find` / `status` for NOTE.md frontmatter |
| `cleanup-state` | `get` / `confirm` the last-run timestamp (`~/.claude/cleanup-state.json`) |
| `worktree-audit` | worktree table + proposed script (dedupes by git common dir) |
| `layout-audit` | artifact layout drift + proposed move script |

Tests: `bash ~/.claude/skills/cleanup/tests/run-tests.sh` (fixtures only; fake `glab` via `GLAB_CMD`).
