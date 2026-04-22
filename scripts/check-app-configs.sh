#!/usr/bin/env bash
# Checks app-managed config files for changes not yet copied to the repo.
# These files are kept as real files (not symlinks) because their apps
# write back to them. Run as a pre-commit hook to catch uncommitted drift.

set -euo pipefail

REPO="$(git rev-parse --show-toplevel)"

# live_path:repo_relative_path
APP_FILES=(
  "$HOME/.claude/settings.json:.claude/settings.json"
  "$HOME/.claude/plugins/installed_plugins.json:.claude/plugins/installed_plugins.json"
  "$HOME/.claude/plugins/blocklist.json:.claude/plugins/blocklist.json"
  "$HOME/.config/karabiner/karabiner.json:.config/karabiner/karabiner.json"
  "$HOME/.config/opencode/opencode.json:.config/opencode/opencode.json"
  "$HOME/.tool-versions:.tool-versions"
)

CHANGED=()

for entry in "${APP_FILES[@]}"; do
  live="${entry%%:*}"
  repo_rel="${entry##*:}"
  repo_file="$REPO/$repo_rel"

  if [[ -f "$live" && -f "$repo_file" ]]; then
    if ! diff -q "$live" "$repo_file" > /dev/null 2>&1; then
      CHANGED+=("$entry")
    fi
  fi
done

[[ ${#CHANGED[@]} -eq 0 ]] && exit 0

echo ""
echo "⚠️  App-managed configs have drifted from the repo:"
for entry in "${CHANGED[@]}"; do
  live="${entry%%:*}"
  repo_rel="${entry##*:}"
  echo ""
  echo "  ── $repo_rel ──"
  diff --unified=2 "$REPO/$repo_rel" "$live" | tail -n +3 | head -40 || true
done

echo ""
printf "Copy to repo and stage for this commit? [y/N] "
read -r response </dev/tty

if [[ "$response" =~ ^[Yy]$ ]]; then
  for entry in "${CHANGED[@]}"; do
    live="${entry%%:*}"
    repo_rel="${entry##*:}"
    cp "$live" "$REPO/$repo_rel"
    git -C "$REPO" add "$repo_rel"
    echo "  ✓ staged $repo_rel"
  done
else
  echo "  Skipped — committing without app-managed changes."
fi
