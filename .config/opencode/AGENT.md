## Spawning long-running processes

When a task requires running a long-running process (e.g. a dev server, watcher, build daemon, test runner in watch mode), do NOT run it in the foreground using the bash tool — it will block.

### Detecting long-running commands

Do NOT maintain a static list of commands. Instead, reason about whether a command is likely long-running before executing it. Strong signals include:

- Subcommands like `update`, `install`, `build`, `start`, `watch`, `serve`, `run`, `test`, `sync`, `bootstrap`
- Unfamiliar project-specific CLIs (e.g. `gdk`, `bazel`, `buck`, `nx`) combined with any of the above subcommands
- Any command in an unfamiliar project where the intent is clearly to compile, fetch, or start something

When uncertain, **ask the user** whether the command is long-running before executing it. Never run it first and then kill it to retry in tmux.

Instead, spawn it in a background tmux pane:

1. Check if a tmux session exists: `tmux list-sessions 2>/dev/null`
2. Create a new window or pane for the process:
   ```
   tmux new-window -t work -n <name>
   tmux send-keys -t work:<window> '<command>' Enter
   ```
3. Continue with other tasks in the current context.
4. To read output later: `tmux capture-pane -t work:<window> -p`
5. To stop the process: `tmux send-keys -t work:<window> C-c`
6. Clean up only when explicitly asked by the user: `tmux kill-window -t work:<window>`. Leave the window open by default so logs can be reviewed after the command finishes.

Only fall back to `cmd &` (background shell process) if tmux is not available.

## Interactive commands

Any command that requires user input or an interactive session (e.g. REPLs, prompts, confirmations, SSH, database shells, package manager interactive modes) must NEVER be run via the bash tool — it will hang.

Always spawn these in a tmux pane so the user can interact directly:

```
tmux new-window -t work -n <name>
tmux send-keys -t work:<window> '<command>' Enter
```

Then inform the user which window/pane to switch to.

## Use GitLab MCP for gitlab related links

You should always try to open every gitlab related link with gitlab mcp whenever it is available. Do not post anything on gitlab without asking for explicit permission.

## Spawn multiple read-only agents

In case the you need to look at many files to understand a problem, spawn multiple explore agents to save time.

## Continuous Learning

Skills live in `/Users/ashvin/.config/opencode/skills/`. When working on a task, if you discover something worth remembering — a better pattern, a missing example, a subtle gotcha, a correction — update the relevant skill file so it's available in future sessions. This is the feedback loop: load skill → do work → learn → write back.

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

| Active skill     | File                             |
| ---------------- | -------------------------------- |
| `go-coder`       | `skills/go-coder/SKILL.md`       |
| `go-reviewer`    | `skills/go-reviewer/SKILL.md`    |
| `shell-coder`    | `skills/shell-coder/SKILL.md`    |
| `shell-reviewer` | `skills/shell-reviewer/SKILL.md` |
| `tofu-coder`     | `skills/tofu-coder/SKILL.md`     |
| `tofu-reviewer`  | `skills/tofu-reviewer/SKILL.md`  |

If no skill was explicitly loaded but the work clearly belongs to one domain, use the appropriate file anyway.
