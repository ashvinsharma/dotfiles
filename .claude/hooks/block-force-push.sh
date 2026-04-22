#!/bin/bash
# PreToolUse hook — blocks force push to main/master
# Allows --force-with-lease (safer) and force pushes to other branches

INPUT=$(cat)
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // ""')

# Only care about git push
echo "$COMMAND" | grep -q 'git push' || exit 0

# Allow --force-with-lease
echo "$COMMAND" | grep -q 'force-with-lease' && exit 0

# Not a force push — allow
echo "$COMMAND" | grep -qE -- '-f\b|--force\b' || exit 0

# Force push detected — check if targeting main or master
CURRENT_BRANCH=$(git branch --show-current 2>/dev/null)
if echo "$COMMAND" | grep -qE '\b(main|master)\b' || [ "$CURRENT_BRANCH" = "main" ] || [ "$CURRENT_BRANCH" = "master" ]; then
  echo "Force push to main/master is blocked. Use a feature branch, or --force-with-lease if you must rewrite history."
  exit 2
fi

exit 0
