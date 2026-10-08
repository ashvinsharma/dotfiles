---
name: gitlab-commit-guideline
description: GitLab commit message rules enforced by Danger (subject/body length, capitalization, full URLs, etc.). Use before writing, amending, or pushing any commit to a GitLab project, and when drafting MR descriptions.
---

Source: https://docs.gitlab.com/development/contributing/merge_request_workflow/#commit-messages-guidelines
If these rules are not met, the MR may fail the Danger checks (`danger-review` job).

## Rules

1. Subject and body separated by a blank line.
2. Subject starts with a capital letter. Prefixes `prefix:` / `[prefix]` are allowed lowercase, as long as the message after them is capitalized (`fix: Use ...` passes, `fix: use ...` fails).
3. Subject ≤ 72 characters.
4. Subject does not end with a period.
5. Body lines ≤ 72 characters each.
6. No emojis in subject or body.
7. Commits changing 30+ lines across 3+ files must describe the changes in the body.
8. Use full URLs for issues, MRs, milestones — never short refs (`gitlab-org/gitlab#123`, `!123`, `%12.3`, `owner/repo#123` for GitHub too). Short refs render as plain text outside GitLab. Danger reports this as an **error**.
9. MR should have ≤ 10 commits (use stacked MRs otherwise).
10. Subject has at least 3 words.

## Style (user preference)

Keep it short. Subject + 1–3 sentence body saying what it does and why, then the related-issue URL. No root-cause essays, no pasted logs — those belong in the issue, not the commit.

```
fix: Fail fast when the runtime cannot join the pod user namespace

Detect the gVisor error "error setting namespace of type user" on pod
sandbox creation and fail the job with a configuration error. Without
this, the job waits in Pending until poll_timeout.

Related to https://gitlab.com/gitlab-org/gitlab/-/work_items/597038
```

## Verify before committing/pushing

Write the message to a file and check line lengths:

```bash
awk '{ printf "%d: %d | %s\n", NR, length($0), $0 }' msg.txt
# subject (line 1) ≤ 72, line 2 empty, every other line ≤ 72
grep -nE '(^|[^/[:alnum:]])([[:alnum:]_.-]+/[[:alnum:]_.-]+)?[#!%][0-9]' msg.txt && echo "short refs found"
```

Show the user the message and the checklist result before amending or force-pushing.
