---
name: decisions
description: Per-epic decision log with stable ids (RJ-D07, RJ-A02) — list decisions in force, add or reverse an entry (user confirms each), check that ids cited in code / MR descriptions / notes still resolve, generate a paste-able index table. Other skills call it to ask "is this already decided?". Use /decisions [list|add|reverse|check|index] [epic-url|iid|MR|issue].
argument-hint: "[list|add|reverse <id>|check|index] [epic-url | epic-iid | log-path]"
allowed-tools: Bash(python3 ~/.claude/skills/decisions/decisions.py:*), Read, Glob, Grep
---

# Decision log

Argue a design question once, cite the id afterwards. Local file is canonical. **Nothing is ever posted to GitLab.**

`$D` below stands for the full command `python3 ~/.claude/skills/decisions/decisions.py` (type it out; a shell
variable won't word-split in zsh and won't match `allowed-tools`). `<log>` = a DECISIONS.md path, or an epic iid/URL.

Format spec (frontmatter, sections, bullet grammar, id rules): `~/.claude/skills/decisions/template.md`.

| | |
|---|---|
| Log file | `~/workspace/ai-workflow-artifacts/workflow-artifacts/<org>/workitem-<epic-iid>/DECISIONS.md` |
| Ids | `<PREFIX>-D<nn>` decision, `<PREFIX>-A<nn>` assumption. Never reused, never renumbered. |
| Prefix | One per epic, own counters. A follow-up epic gets its own prefix (`RJ2`); nothing is shared across files. |
| Sections | `Settled` · `Reversed` (keeps id, says what replaced it) · `Assumptions` (relied on, unproven) |
| Bullet | `- **RJ-D01** · **Lead clause.** One sentence why. ([!123](url))` |

New log: `$D init --epic <epic-url> --prefix <P> [--repo <dir> ...]` (refuses to overwrite).

## Resolve the epic

| Given | Do |
|---|---|
| epic URL (`…/groups/<g>/-/work_items/<iid>` or `/epics/<iid>`) / bare iid | `$D path <it>` → log file. An MR/issue URL is **rejected (exit 2)**: resolve its epic first |
| issue | walk up to the nearest epic that has a log (read-only GraphQL below) |
| MR | MR has no epic parent: use `closes_issues` → walk; else `epic:` in its `NOTE.md` frontmatter; else ask |
| file path | use as is |

```bash
glab api graphql -f query='query { project(fullPath: "<repo>") { workItems(iid: "<iid>") {
  nodes { widgets { ... on WorkItemWidgetHierarchy { parent { iid title } } } } } } }'
```

Use `group(fullPath:)` when the work item is itself an epic. Structure beats guesswork: if the walk and the note's `epic:` disagree, **stop and ask**. No log for the epic → say so; offer `init`; do not create one unprompted. `glab api` is GET/GraphQL **query** only here.

## Commands

| Command | Does |
|---|---|
| `list` | `$D list <log> [--all] [--json]` decisions in force + assumptions (`--all` adds Reversed) |
| `add` | draft → `$D add <log> --section settled\|assumptions --text '**Lead.** Why. ([!1](url))' --dry-run` → show the diff → **wait for ok** → rerun without `--dry-run` |
| `reverse <id>` | add the replacement first (above), then `$D reverse <log> <id> --by <new-id> --why '…' --dry-run` → show diff → **wait for ok** → rerun. No `--by` if nothing replaces it. |
| `check` | `$D check <log> [--stdin] [--file F ...]` — greps the frontmatter `repos` (git), every `**/NOTE.md` under the log's folder (+ `note_globs`), and stdin. Status per hit: `settled` · `reversed` (`-> replacement`) · `assumption` · `unknown`. Exit 1 on `unknown`. |
| `index` | `$D index <log> [--live]` paste-able markdown table on stdout (`--live` drops Reversed). Show it; the user pastes it wherever they want. |
| `lint` | `$D lint <log>` duplicate ids, wrong section, unnumbered bullets, dangling replacements |
| `number` | `$D number <log>` numbers hand-written bullets that lack an id (idempotent; `--dry-run`) |

Checking an MR/issue description offline-safe, read-only:

```bash
glab api "projects/<id>/merge_requests/<iid>" | jq -r .description | $D check <log> --stdin --no-repos --no-notes
```

Report ids, not counts: which are `reversed` (the code stands on moved ground → name the replacement) and which are `unknown` (typo or never logged).

## Writing entries

- **Decision** = confirmed by the user or an approved design/MR. Anything inferred is an **Assumption**, never a Decision.
- Lead clause is the decision, in bold. One sentence of why. Source links are full URLs (permalink to a commit SHA when pointing at code).
- Contradicts an existing id? That is a reversal, not a new decision: add the new one, then `reverse` the old one.
- **Promote an assumption** once proven: add a new `D` in Settled citing the evidence, then `reverse <A-id> --by <D-id> --why '<evidence>'` (renders as "Promoted to"). Disproved: `reverse <A-id> --why '<evidence>'`.
- Never edit the id of an existing bullet. Hand edits are fine; run `lint` after. Hand-typed ids must keep the ` · ` separator after the bold id (`- **RJ-D07** · **Lead.** …`); `lint` flags anything else and `number` refuses to touch it.

## Citing ids

| Where | Form |
|---|---|
| Code comment | `// See RJ-D07.` (no URL; `check` finds it) |
| MR description / review reply | `RJ-D07` plus the lead clause once, never re-argue |
| `NOTE.md` → "Decisions in force" | `- RJ-D07 — <lead clause>` |

## Calling from other skills

"Is this review comment / question already covered by a decision?"

```bash
python3 ~/.claude/skills/decisions/decisions.py find <epic-iid|log> <term> [<term> ...] --json   # all terms, case-insensitive
python3 ~/.claude/skills/decisions/decisions.py list <epic-iid|log> --json                       # whole log in force
```

```json
[{"id": "RJ-D07", "kind": "decision", "status": "settled", "lead": "…", "why": "…",
  "sources": ["[!7643](https://…)"], "replaced": null, "text": "full bullet"}]
```

- `status`: `settled` | `assumption` | `reversed` (only with `--all`). For `reversed`, `replaced = {"how": "Reversed by", "by": "RJ-D09", "why": "…"}`.
- Exit codes (all commands):

  | rc | Meaning | Caller does |
  |---|---|---|
  | 0 | ok / hit | use the JSON |
  | 1 | `find`: no hit · `lint`/`check`: findings | not covered / report findings |
  | 2 | usage or IO error, **incl. an MR/issue URL or typo'd arg** | real error: surface it, never read as "no decisions" |
  | 3 | valid epic, **no log for it** | treat as "no decisions logged" |

  Pass an **epic** (iid / epic URL / log path). For an MR or issue, resolve its epic first (see *Resolve the epic*).
- `find` is keyword matching only. The caller judges coverage by reading `lead` + `why`. Try 2–3 synonym terms before concluding "not covered".
- Covered by `settled` → cite the id; do not re-litigate. A reply is still optional (skip nits). `assumption` → "not decided", treat as open. `reversed` → follow `replaced.by`.
- Callers never write the log; to record something they hand the draft to `/decisions add`.

## Rules

- Never post to GitLab (epic description, notes, MR). The index is for the user to paste.
- `add` / `reverse` always show the diff and wait for an explicit ok. `number`, `lint`, `check`, `list`, `index` are read-only or idempotent.
- Do not backfill or seed logs unprompted; create entries when a decision is actually made with the user.
- Tests: `WF_TEST_DIR=<scratch> python3 -I ~/.claude/skills/decisions/test_decisions.py` (fixtures only).
