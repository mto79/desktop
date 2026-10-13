#!/usr/bin/env bash

# .githooks/pre-commit checks every commit for private information, but git runs the
# hooks in .githooks only once core.hooksPath says so, and that is set by the installer,
# which this machine is long past.
REPO="$HOME/.local/share/desktop"
if [[ $(git -C "$REPO" config --get core.hooksPath) != .githooks ]]; then
  git -C "$REPO" config core.hooksPath .githooks || exit 1
  echo "  commits to the desktop repository are checked for private information first"
fi
