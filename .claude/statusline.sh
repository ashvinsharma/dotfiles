#!/usr/bin/env bash
# Claude Code custom status line
input=$(cat)

MODEL=$(echo "$input" | jq -r '.model.display_name // "unknown"')
CWD=$(echo "$input" | jq -r '.cwd // .workspace.current_dir // ""')
DIR="${CWD##*/}"
PCT=$(echo "$input" | jq -r '(.context_window.used_percentage // 0) | floor' 2>/dev/null || echo 0)

# Git branch (fast, uses CWD)
BRANCH=$(git -C "$CWD" branch --show-current 2>/dev/null)
if [[ -z "$BRANCH" ]]; then
  BRANCH=$(git -C "$CWD" rev-parse --short HEAD 2>/dev/null)
fi

# Context bar (10 blocks)
FILLED=$(( PCT * 10 / 100 ))
EMPTY=$(( 10 - FILLED ))
BAR=""
for (( i=0; i<FILLED; i++ )); do BAR+="█"; done
for (( i=0; i<EMPTY; i++ )); do BAR+="░"; done

# Context emoji based on usage
if   (( PCT >= 80 )); then CTX_EMOJI="🔴"
elif (( PCT >= 50 )); then CTX_EMOJI="🟡"
else                       CTX_EMOJI="🟢"
fi

# Branch part (only if in a git repo)
if [[ -n "$BRANCH" ]]; then
  BRANCH_PART=" 🌿 $BRANCH"
else
  BRANCH_PART=""
fi

echo "🤖 $MODEL  ${CTX_EMOJI} ${BAR} ${PCT}%  📁 $CWD$BRANCH_PART"
