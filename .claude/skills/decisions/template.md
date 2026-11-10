---
prefix: RJ
epic: https://gitlab.com/groups/gitlab-org/-/work_items/00000
repos:
  - ~/workspace/gitlab-org/gitlab-runner
# note_globs: optional extra globs for `check` (relative to this file's folder, or absolute / ~)
# note_globs:
#   - "**/NOTE.md"
---

# <Workstream> decision log

<!-- Format spec: ~/.claude/skills/decisions/template.md. This file is canonical; nothing is posted to GitLab. -->

## Settled

- **RJ-D01** · **Lead clause stating the decision.** One sentence of why. ([!123](https://gitlab.com/gitlab-org/gitlab-runner/-/merge_requests/123), [#45](https://gitlab.com/gitlab-org/gitlab-runner/-/issues/45))

## Reversed

- **RJ-D02** · **Old decision that no longer holds.** Why it was made. ([#46](https://gitlab.com/gitlab-org/gitlab-runner/-/issues/46)) — Reversed by **RJ-D01**: what changed.

## Assumptions

- **RJ-A01** · **Thing we rely on but have not proven.** What would prove or disprove it. ([!124](https://gitlab.com/gitlab-org/gitlab-runner/-/merge_requests/124))

<!--
FORMAT
  One file per epic: workflow-artifacts/<org>/workitem-<epic-iid>/DECISIONS.md
  Each epic owns its prefix and its counters. Nothing is shared across files (a Phase 2 epic gets its own prefix, e.g. RJ2).

FRONTMATTER
  prefix       required  ^[A-Z][A-Z0-9]*$   digits allowed (RJ2); no hyphen
  epic         required  epic URL
  repos        optional  git repos `check` greps for cited ids
  note_globs   optional  extra globs `check` scans; default is **/NOTE.md under this file's folder

SECTIONS (the section is the status; any other `## ` heading is ignored)
  ## Settled      decisions in force                        ids <PREFIX>-D<nn>
  ## Reversed     decisions that no longer hold (keep id)   ids <PREFIX>-D<nn> or <PREFIX>-A<nn>
  ## Assumptions  relied on, unproven                       ids <PREFIX>-A<nn>

BULLET GRAMMAR (one bullet per entry, starts at column 0, continuation lines are indented)
  - **<PREFIX>-D<nn>** · **<Lead clause>.** <One sentence why.> ([<ref>](<url>), ...)
  An unnumbered bullet (`- **Lead.** Why. (src)`) is numbered by `decisions.py number`.
  A Reversed bullet ends with one of:
    — Reversed by **<new-id>**: <what replaced it and why>.
    — Promoted to **<new-id>**: <evidence that confirmed the assumption>.
    — Reversed: <why>.            (nothing replaced it)

ID RULES
  Regex: (?<![\w-])<PREFIX>-[DA]\d+(?!\w)       RJ-D1 never matches inside RJ-D10; RJ never matches RJ2-D01
  Ids are never reused and never renumbered. Next id = max seen anywhere in the file + 1 (Reversed included, no gap-fill).
  Reversing moves the bullet to ## Reversed and keeps its id. Add the replacement first, then reverse.
  Promoting a confirmed assumption: add a new D in Settled with the evidence, then move the A bullet to Reversed
  with "Promoted to <D-id>". A disproved assumption moves to Reversed with "Reversed: <why>".

PROVENANCE
  Decision  = confirmed by the user (or an approved design/MR). Assumption = inferred or unverified; never a Decision.
-->
