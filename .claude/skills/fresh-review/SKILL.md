---
name: fresh-review
description: Fresh-eyes review of a GitLab MR — a read-only reviewer subagent that receives ONLY the repo, base/head branch, checkout path, the linked issue text verbatim and neutral facts (no design rationale, no MR description, no notes, no prior reviews, no chat), returns ranked findings with file:line and a failure scenario, and this session verifies every finding before relaying it. Use after implementing an MR for an unbiased review, or /fresh-review [mr-url | group/project!N | iid].
argument-hint: "[mr-url | group/project!N]"
allowed-tools: Bash(python3 ~/.claude/skills/fresh-review/scripts/brief.py:*), Agent, Read, Grep, Bash(git diff:*), Bash(git log:*), Bash(git show:*)
---

# Fresh-eyes review

The value is the **absence of shared context**: the reviewer builds its own model from the issue and the diff, so it can catch what the author rationalised away.

## 1. Build the brief (deterministic)

```bash
python3 ~/.claude/skills/fresh-review/scripts/brief.py --project <group/project> --iid <N> [--worktree <dir>] [--fact "<neutral fact>"]...
```

The script reads only the MR's branches and its closing issue(s). It never reads the MR description, notes or reviews, so it cannot leak them. The diff base is the MR's **target** branch (stacked MRs don't target main).

- No worktree for the head branch → pass `--worktree`, or tell the user. Never create one yourself.
- No linked issue → ask the user for the issue text; do not paraphrase from memory.
- `--fact`: only bare, checkable facts the reviewer can't easily find (e.g. "gitlab-org/fleeting/taskscaler is a dependency of this repo"). Never an interpretation, a trade-off or a reason.

## 2. Spawn

`Agent` with `subagent_type: "reviewer"` (read-only: no Write/Edit). **Never `fork`**: a fork inherits this conversation, which is exactly what must not be shared. Prompt = the script's output, verbatim, nothing added.

Do not add: design decisions, why-it-was-built-this-way, known trade-offs, earlier review results, the MR description, anything from this chat.

## 3. Verify before relaying

Findings are claims. For each: open the cited line, run the code path or test if cheap, check the base branch. Then report:

```
CONFIRMED   <file:line> — <claim> — <scenario>        (how verified)
UNCONFIRMED <file:line> — <claim>                      (why not verifiable)
DISMISSED   <file:line> — <claim> — <one-line reason>
```

Ranked most severe first. Include the reviewer's "Verified sound" in one line. Don't fix anything unless asked.

## Overlap

| | sees | question it answers |
|---|---|---|
| `/fresh-review` | issue + diff + checkout only | did I build the right thing, and is it correct? One generalist, no shared context |
| `/mr-review <url>` | the diff only, four lenses (correctness, coverage, security, deps) via `parallel-review` | is each lens satisfied? No issue text |
| `/review-and-fix` | the branch diff, auto-fixes | pre-PR gate |

For security-sensitive changes run `/fresh-review` **and** `/mr-review`; keep the two reports separate.
