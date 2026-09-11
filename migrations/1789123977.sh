#!/usr/bin/env bash

# The lazygit helpers were renamed to desktop-git-commit, desktop-git-branch and
# desktop-git-housekeeping, and they now run from bin/ like every other command instead of
# being copied into ~/.local/bin. fish puts ~/.local/bin first, so the copies were what a
# terminal ran, and an edit to bin/ did nothing there until it was copied over again.
#
# Two things on an existing machine still point at the old names:
#
#   ~/.config/lazygit/config.yml  copied from config/, so it still calls lazygit-*. The
#                                 names are rewritten in place rather than the file being
#                                 copied again, which would throw away local edits.
#   ~/.local/bin/lazygit-*        the old copies. Each is removed only if it matches a
#                                 version this repo once committed; one edited by hand is
#                                 left where it is and reported.
#
# Safe to re-run: a rewritten config has nothing left to match and a removed file is gone.

set -uo pipefail

DESKTOP="${HOME}/.local/share/desktop"
CONFIG="${HOME}/.config/lazygit/config.yml"

if [[ -f $CONFIG ]]; then
  sed -i \
    -e 's/\blazygit-gen-commit\b/desktop-git-commit/g' \
    -e 's/\blazygit-gen-branch\b/desktop-git-branch/g' \
    -e 's/\blazygit-housekeeping\b/desktop-git-housekeeping/g' \
    "$CONFIG" || exit 1
  echo "  pointed ${CONFIG} at the desktop-git-* commands"
fi

for name in lazygit-gen-commit lazygit-gen-branch lazygit-housekeeping; do
  copy="${HOME}/.local/bin/${name}"
  [[ -f $copy ]] || continue

  blob=$(git hash-object "$copy" 2>/dev/null) || blob=""
  if [[ -n $blob ]] &&
    git -C "$DESKTOP" log --all --format= --raw --no-abbrev -- "bin/${name}" 2>/dev/null |
    awk '{ print $4 }' | grep -qx "$blob"; then
    rm -f "$copy"
    echo "  removed ${copy}"
  else
    echo "  left ${copy}: it differs from every committed version, so it may be yours"
  fi
done
