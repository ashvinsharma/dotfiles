## Failure visibility

At the end of any response where something failed, did not complete, or requires user action to unblock, add a ❌ section listing each open item. This ensures failures catch the user's eye even when skimming.

## AI Workflow Artifacts

All plans, designs, critiques, and implementation specs should be saved to `~/workspace/ai-workflow-artifacts/`. Structure: `workflow-artifacts/{org}/{repo}/{issue-id|workitem-id|general-date-slug}/`. Use `/artifact` to save. Offer to save at the end of any conversation where a plan or document was produced.

## Dry run

A dry run means manually tracing/walking through code logic line-by-line without executing it — a mental or paper-based simulation to verify correctness. When asked for a dry run, trace through the relevant code paths manually showing variable states and which branches are taken. Do NOT make changes, run tests, or simulate via execution.

## Memory

Do not use the memory system unless explicitly asked by the user.

## Proactive command suggestions

When context matches a command's purpose, suggest it with one line — do not lecture, do not repeat the suggestion if already declined. Format: `Tip: this looks like a good case for \`/command\` — want me to run it?`

| Context signal | Suggest |
|---|---|
| Start of conversation, user mentions what they're working on today | `/standup` |
| User is designing or starting a new feature | `/office-hours` → `/plan-eng-review` |
| Startup/product decision (scope, priorities, what to build) | `/plan-ceo-review` |
| User pastes or links a GitLab MR URL | `/mr [URL]` |
| User is confused by or asking about a specific comment/thread | `/understand [URL]` |
| User is about to open a PR or asks if code is ready | `/walkthrough` → `/review-and-fix` |
| User is debugging, describes unexpected behaviour | `/investigate` |
| User mentions production, migrations, security-sensitive paths, or CVEs | `/guard` |
| User asks "what have I been working on" or it's end of week | `/retro` |
| User starts editing files in many directories at once | `/freeze [dir]` |

Keep suggesting the relevant command each time the context applies, until the user either uses it or explicitly says they don't want the suggestion. Never suppress a suggestion unless explicitly told to.

## Lint and linter configuration changes require explicit approval

Never modify linter configuration files (`.golangci.yml`, `.golangci.yaml`, `.eslintrc`, `pyproject.toml` linter sections, etc.) without first explaining the proposed change and getting explicit user approval. This includes adding exclusions, disabling rules, or changing severity levels.

Lint rules are a safety net. Silencing them — especially for broad patterns — can hide real bugs and erode the team's trust in the linter. Always treat a linter complaint as signal: fix the underlying code first, and only ask to change the config if there is a genuine false-positive case to make.

## Use permalinks when referencing code

When mentioning a keyword, function, variable, or file from a repository, always link to a permalink anchored to a specific commit on the main branch — never a branch name (which moves) or a bare file path. Use the format:

`https://gitlab.com/<org>/<repo>/-/blob/<sha>/path/to/file.go#L42`

Obtain the SHA with `git rev-parse origin/main` (or `origin/master`) for the relevant repo at the time of writing.

## Listing GitLab MRs

Always use the global API to list MRs — never `glab mr list` which is scoped to the current repo only:

```
glab api "merge_requests?author_username=ashvins&state=opened&per_page=50"
```

Then fetch each MR individually (`projects/{id}/merge_requests/{iid}`) to get `head_pipeline` status.

## Use GitLab MCP for gitlab related links
You should always try to open every gitlab related link with gitlab mcp whenever it is available. Do not post anything on gitlab without asking for explicit permission.

## Spawn multiple read-only agents
For read-only context gathering across multiple independent files, modules, or questions, spawn parallel Explore agents — one per distinct area or question. Run all in parallel in a single message. Consolidate all results before acting. Over-parallelising is preferable to under-parallelising when gathering read-only context. For tasks requiring a single targeted read, do not spawn agents.

## Continuous Learning

Skills live in `/Users/ashvin/.claude/skills/`. When working on a task, if you discover something worth remembering — a better pattern, a missing example, a subtle gotcha, a correction — update the relevant skill file so it's available in future sessions. This is the feedback loop: load skill → do work → learn → write back.

### When to update a skill file

Update when you have discovered:
- A pattern or idiom that is clearly better than, or not covered by, the existing content
- An edge case, footgun, or correction to something already documented
- A new tool, flag, or technique that fits naturally within the skill's scope

The new knowledge must be **generalizable** — it applies beyond this specific project and this specific task.

### When NOT to update

- Project-specific conventions that don't apply elsewhere
- A single data point or unverified experiment — wait until the pattern is confirmed
- Anything you're uncertain about — mention it to the user instead and let them decide
- Minor personal style preferences with no objective benefit

### Protocol

1. **Announce first.** Before touching the file, tell the user: what you found, why it's worth keeping, and which skill file you're updating. Give them a moment to stop you.
2. **Then update.** Make a surgical, additive edit to the relevant `SKILL.md`. Preserve all existing content and formatting. Match the tone, structure, and code-example style already present. Add, don't delete — unless something is demonstrably wrong, in which case correct it and say so.
3. **Offer to commit.** After updating, ask the user whether they want to commit the skill file change. Do not commit without explicit approval.

### Which file to update

| Active skill | File |
|---|---|
| `go-coder` | `skills/go-coder/SKILL.md` |
| `go-reviewer` | `skills/go-reviewer/SKILL.md` |
| `go-security` | `skills/go-security/SKILL.md` |
| `shell-coder` | `skills/shell-coder/SKILL.md` |
| `shell-reviewer` | `skills/shell-reviewer/SKILL.md` |
| `shell-security` | `skills/shell-security/SKILL.md` |
| `tofu-coder` | `skills/tofu-coder/SKILL.md` |
| `tofu-reviewer` | `skills/tofu-reviewer/SKILL.md` |
| `tofu-security` | `skills/tofu-security/SKILL.md` |
| `security-reviewer` agent | `agents/security-reviewer.md` |
| `parallel-review` | `skills/parallel-review/SKILL.md` |
| `tmux` | `skills/tmux/SKILL.md` |

If no skill was explicitly loaded but the work clearly belongs to one domain, use the appropriate file anyway.
