#!/bin/bash
# SessionStart hook — repo/branch context + today's commits + GitLab MR/todo summary via MCP

REPO=$(basename "$(git rev-parse --show-toplevel 2>/dev/null)" 2>/dev/null)
BRANCH=$(git branch --show-current 2>/dev/null)

# Not in a git repo — skip
[ -z "$REPO" ] && exit 0

echo "SESSION START"
echo "============="
echo "Repo:   $REPO"
echo "Branch: $BRANCH"

# Today's commits
COMMITS=$(git log --oneline --since="midnight" --format="%h %s" 2>/dev/null | head -5)
if [ -n "$COMMITS" ]; then
  echo ""
  echo "TODAY'S COMMITS:"
  echo "$COMMITS" | sed 's/^/  /'
fi

# Open MRs (glab as fallback — MCP preferred but can't be called from shell hooks)
echo ""
echo "OPEN MRs:"
glab mr list --author=@me --state=opened --output=text 2>/dev/null \
  | awk '{print "  " $0}' \
  | head -5 \
  || echo "  (run /mr <url> or /standup for full GitLab context)"

# Pending todos
TODOS=$(glab api "/todos?state=pending&per_page=5" 2>/dev/null \
  | jq -r '.[] | "  [\(.action_name | ascii_upcase)] \(.project // {} | .name // "gitlab") — \(.body // .title // "" | .[0:70])"' 2>/dev/null)
if [ -n "$TODOS" ]; then
  echo ""
  echo "PENDING TODOS:"
  echo "$TODOS"
fi

echo ""
echo "GitLab MCP is active — use it for detailed MR/issue/todo queries this session."
