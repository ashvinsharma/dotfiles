---
description: Understand what a GitLab comment or thread is asking — plain-language explanation of the concern and what action (if any) is expected from you
---

Given a GitLab comment URL or thread URL, explain in plain language what the reviewer is saying, what concern or question they are raising, and what (if anything) you are expected to do in response.

Argument: `$ARGUMENTS` — a GitLab comment or thread URL

---

## Step 1 — Fetch the comment and context

Use the GitLab MCP to fetch:
- The specific comment or note
- The full thread it belongs to (all replies in order)
- The diff hunk the comment is attached to (file path + surrounding lines)
- The MR title and description (for overall context)

---

## Step 2 — Understand the reviewer's concern

Read the comment carefully. Identify:
1. **What they observed** — what in the code caught their attention?
2. **Why they flagged it** — is this a bug, design concern, style issue, missing test, security risk, unclear naming, or performance issue?
3. **What they are asking** — a question, a requested change, or a suggestion?

If the comment is unclear or uses shorthand, infer intent from the diff context and thread replies. Explain your inference.

---

## Step 3 — Explain the code context

Show the relevant diff hunk. In 1-3 sentences, explain what the code is doing at that point — without assuming the user has the surrounding context loaded in their head.

---

## Step 4 — What is expected from you

One of:
- **Change required**: [describe the specific change being asked for]
- **Question to answer**: [what the reviewer is asking — answer it if you can]
- **Your call**: [the reviewer left a suggestion; you can take it or explain why you disagree]
- **No action needed**: [the comment is informational or already resolved]

---

## Output format

```
COMMENT FROM @[author]
File: [file path, line range]
Thread: [N replies]

WHAT THEY OBSERVED
[1-2 sentences: what in the code caught their attention]

THEIR CONCERN
[1-2 sentences: why they flagged it]

CODE CONTEXT
[diff hunk]
[1-2 sentence explanation of what this code does]

WHAT'S EXPECTED FROM YOU
[Change required | Question to answer | Your call | No action needed]
[Specific description]
```
