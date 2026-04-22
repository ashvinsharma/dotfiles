# Critique Plan

Run a saved plan through GPT-5 (via GitLab Duo in opencode) and save the critique back to the artifacts repo.

## Steps

1. **Identify the plan file** — ask the user if not clear from context, otherwise use the most recent plan:
   - Derive project key from CWD: strip `~/workspace/` → e.g. `gitlab-org/gitlab-runner`
   - Find the latest version dir: `ls ~/workspace/ai-workflow-artifacts/workflow-artifacts/{project}/{identifier}/a-plan/`
   - Plan file: `a-plan/v{nn}/plan-v{nn}.md`

2. **Run the critique via opencode**:
   ```bash
   opencode run \
     -m gitlab/duo-chat-gpt-5-4 \
     -f {plan_file} \
     "You are a senior engineer reviewing an implementation plan. Critique it rigorously and directly:
   - Flaws or incorrect assumptions in the approach
   - Missing edge cases or failure modes
   - Security or performance risks
   - Simpler alternatives worth considering
   - What you would do differently
   Be specific. Reference the plan content directly." \
     2>/dev/null | perl -pe 's/\e\[[0-9;]*m//g' > {critique_file}
   ```
   Output path: `a-plan/v{nn}/critique-gpt5-v{nn}.md`

3. **Git commit**:
   ```bash
   git -C ~/workspace/ai-workflow-artifacts add .
   git -C ~/workspace/ai-workflow-artifacts commit -m "feat({project}/{identifier}): add gpt5 critique v{nn}"
   ```

4. **Summarise** the key critique points for the user and ask if they want to produce a revised plan (which would be `v{nn+1}`).

## Notes

- Default model is `gitlab/duo-chat-gpt-5-4` — genuinely different from Claude, gives adversarial perspective
- If opencode returns an auth error, tell the user to run `oc` once to refresh the token
- Never overwrite an existing critique file — if one exists for this version, increment or ask
