#!/usr/bin/env bash
# Adopt files that already exist at the stow target into the repo.
#
# Default (stow): moves the live file into the repo, creates a symlink back.
#   scripts/adopt.sh
#
# --cp / -c: copies the live file into the repo and registers it as copy-managed
#   (adds to scripts/app-files and .stow-local-ignore). Use this when the tool
#   does not support symlinks.
#   scripts/adopt.sh --cp
set -euo pipefail

REPO="$(cd "$(dirname "$0")/.." && pwd)"
STOW_DIR="$(dirname "$REPO")"
PACKAGE="$(basename "$REPO")"

MODE="stow"
if [[ "${1:-}" == "--cp" || "${1:-}" == "-c" ]]; then
  MODE="cp"
fi

cd "$STOW_DIR"

echo "==> dry-run: files that would be adopted"
# stow --adopt -n outputs "LINK: <rel-path> => <target>" for each file it would move
RAW="$(stow -n --adopt -v -t "$HOME" "$PACKAGE" 2>&1 || true)"
# Extract the relative paths from LINK lines
PATHS="$(echo "$RAW" | awk '/^LINK:/ { sub(/^LINK: /, ""); sub(/ =>.*/, ""); print }' || true)"

if [[ -z "$PATHS" ]]; then
  echo "     no conflicts found — nothing to adopt"
  exit 0
fi

echo "$PATHS"
echo ""

if [[ "$MODE" == "cp" ]]; then
  printf "Copy into repo and register as copy-managed? [y/N] "
  read -r response </dev/tty
  [[ "$response" =~ ^[Yy]$ ]] || { echo "Aborted."; exit 0; }

  while IFS= read -r rel; do
    [[ -z "$rel" ]] && continue

    # Copy live file into repo
    mkdir -p "$(dirname "$REPO/$rel")"
    cp "$HOME/$rel" "$REPO/$rel"
    echo "     copied: $rel"

    # Add to app-files if not already present
    if ! grep -qxF "$rel" "$REPO/scripts/app-files"; then
      echo "$rel" >> "$REPO/scripts/app-files"
      echo "     registered in scripts/app-files"
    fi

    # Add to .stow-local-ignore if not already present (escape dots for regex)
    escaped="${rel//./\\.}"
    if ! grep -qxF "$escaped" "$REPO/.stow-local-ignore"; then
      echo "$escaped" >> "$REPO/.stow-local-ignore"
      echo "     added to .stow-local-ignore"
    fi
  done <<< "$PATHS"

else
  printf "Adopt these files into the repo (stow)? [y/N] "
  read -r response </dev/tty
  [[ "$response" =~ ^[Yy]$ ]] || { echo "Aborted."; exit 0; }

  stow --adopt -t "$HOME" "$PACKAGE"
fi

echo ""
echo "==> review changes before committing:"
git -C "$REPO" diff
git -C "$REPO" status --short
echo "==> review the diff above, then commit"
