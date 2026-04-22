# Save Artifact

Save the current plan, critique, or implementation artifact to the ai-workflow-artifacts repo.

## Steps

1. **Determine project key** from CWD:
   - Strip `~/workspace/` (or `/Users/ashvin/workspace/`) prefix
   - Result: e.g. `gitlab-org/gitlab-runner`
   - If not under `~/workspace/`, ask the user what project key to use

2. **Determine identifier** — ask the user if not obvious from context:
   - `issue-{id}` for GitLab issues (e.g. `issue-12345`)
   - `workitem-{id}` for GitLab work items
   - `general-{YYYYMMDD}-{short-slug}` for non-issue work (e.g. `general-20260326-agent-notifications`)

3. **Determine artifact type and subpath**:
   - `plan` → `a-plan/v{nn}/plan-v{nn}.md` (auto-increment: check existing `v*` dirs)
   - `critique` → `a-plan/v{nn}/critique-v{nn}.md` (same version as the plan it critiques)
   - `implementation` → `b-implement/iter{nn}/implementation-iter{nn}.md`
   - `review` → `b-implement/iter{nn}/review-iter{nn}.md`
   - `misc` → `misc/{filename}.md`

4. **Construct full path**:
   ```
   ~/workspace/ai-workflow-artifacts/workflow-artifacts/{project}/{identifier}/{subpath}
   ```

5. **Write the artifact** — use the content from the current conversation (the plan, design, or document being saved)

6. **Git commit**:
   ```
   git -C ~/workspace/ai-workflow-artifacts add .
   git -C ~/workspace/ai-workflow-artifacts commit -m "feat({project}/{identifier}): save {type} v{nn}"
   ```

7. **Confirm** the saved path to the user.

## Notes

- Never overwrite an existing versioned file — always increment
- If the identifier directory doesn't exist yet, create it (including `a-plan/`, `b-implement/`, `misc/` as needed)
- The artifact content should be the actual document from the conversation, not a summary
