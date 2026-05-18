# Save Artifact

Save the current plan, critique, or implementation artifact to the ai-workflow-artifacts repo.

## Steps

1. **Determine the base path** from CWD and context:
   - Strip `~/workspace/` (or `/Users/ashvin/workspace/`) prefix for the project key
   - **Single-repo work** → use `{org}/{project}` (e.g. `gitlab-org/gitlab-runner`)
   - **Cross-repo epic** (work spans multiple repos or belongs to an org-level epic) →
     use `{org}` only (e.g. `gitlab-org`). This is the case when the identifier is a
     workitem/epic that isn't scoped to one repo.
   - If not under `~/workspace/`, ask the user what base path to use.

2. **Determine identifier** — ask the user if not obvious from context:
   - `workitem-{id}` for GitLab work items / epics
   - `issue-{id}` for GitLab issues
   - `general-{YYYYMMDD}-{short-slug}` for non-issue work with no stable external ID
   - **MRs are never top-level identifiers** — they always nest inside their parent
     epic/workitem under a `{project}/mr-{id}/` subdirectory (see Step 4).

3. **Determine artifact type and subpath**:
   - `plan` → `a-plan/v{nn}/plan-v{nn}.md` (auto-increment: check existing `v*` dirs)
   - `critique` → `a-plan/v{nn}/critique-v{nn}.md` (same version as the plan it critiques)
   - `implementation` → `b-implement/iter{nn}/implementation-iter{nn}.md`
   - `review` → `b-implement/iter{nn}/review-iter{nn}.md`
   - `misc` → `misc/{filename}.md`

4. **Construct full path**:

   Single-repo work item:
   ```
   workflow-artifacts/{org}/{project}/{identifier}/{subpath}
   ```

   Cross-repo epic:
   ```
   workflow-artifacts/{org}/{identifier}/{subpath}
   ```

   MR nested inside a parent epic (project subdirectory prevents ID collisions across repos):
   ```
   workflow-artifacts/{org}/{epic-identifier}/{project}/mr-{id}/{subpath}
   ```

   Examples:
   ```
   # Runner MR !6641 belonging to epic workitem-21159
   workflow-artifacts/gitlab-org/workitem-21159/gitlab-runner/mr-6641/a-plan/v01/plan-v01.md

   # Rails MR !231517 belonging to the same epic
   workflow-artifacts/gitlab-org/workitem-21159/gitlab/mr-231517/a-plan/v01/plan-v01.md
   ```

5. **Write the artifact** — use the content from the current conversation (the plan, design,
   or document being saved).

6. **Git commit**:
   ```
   git -C ~/workspace/ai-workflow-artifacts add .
   git -C ~/workspace/ai-workflow-artifacts commit -m "feat({base-path}/{identifier}): save {type} v{nn}"
   ```

7. **Confirm** the saved path to the user.

## Notes

- Never overwrite an existing versioned file — always increment
- If the identifier directory doesn't exist yet, create it (including `a-plan/`,
  `b-implement/`, `misc/` as needed)
- The artifact content should be the actual document from the conversation, not a summary
- **MR nesting rule**: MRs belong inside their parent epic under `{project}/mr-{id}/`,
  not as standalone top-level dirs. Nesting under `{project}/` prevents ID collisions
  between MRs from different repos (e.g. `gitlab-runner/mr-6641` vs `gitlab/mr-6641`).
  This keeps the full arc of work (plan → MR → review → successor MR) navigable from
  one root.
- **Cross-repo epic rule**: When a workitem/epic spans multiple repos (runner, rails, gdk,
  etc.), drop the `{project}` segment and root at `{org}`. Avoids artificial splits like
  `gitlab-org/gitlab/workitem-21159` vs `gitlab-org/gitlab-runner/workitem-21159`.
