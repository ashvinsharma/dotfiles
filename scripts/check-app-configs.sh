#!/usr/bin/env bash
# Checks copy-managed config files for changes not yet synced to the repo.
# These files are kept as real files (not symlinks) because their apps don't support symlinks.
# Run as a pre-commit hook to catch uncommitted drift.
set -euo pipefail

REPO="$(git rev-parse --show-toplevel)"

CHANGED=()

while IFS= read -r rel || [[ -n "$rel" ]]; do
  [[ -z "$rel" || "$rel" == \#* ]] && continue
  live="$HOME/$rel"
  repo_file="$REPO/$rel"

  if [[ -f "$live" && -f "$repo_file" ]]; then
    if ! diff -q "$live" "$repo_file" >/dev/null 2>&1; then
      CHANGED+=("$rel")
    fi
  fi
done <"$REPO/scripts/app-files"

[[ ${#CHANGED[@]} -eq 0 ]] && exit 0

echo ""
echo "⚠️  Copy-managed configs have drifted from the repo:"
for rel in "${CHANGED[@]}"; do
  echo ""
  echo "  ── $rel ──"
  diff --unified=2 "$REPO/$rel" "$HOME/$rel" | tail -n +3 | head -40 || true
done

echo ""
printf "Copy to repo and stage for this commit? [y/N] "
read -r response </dev/tty

if [[ "$response" =~ ^[Yy]$ ]]; then
  for rel in "${CHANGED[@]}"; do
    cp "$HOME/$rel" "$REPO/$rel"
    git -C "$REPO" add "$rel"
    echo "  ✓ staged $rel"
  done
fi
