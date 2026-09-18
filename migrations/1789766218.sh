#!/usr/bin/env bash

# The GitHub CLI repository on machines that added it before GitHub moved its signing key.
#
# The repo file GitHub used to publish fetched the key from Ubuntu's keyserver by ID:
#
#   gpgkey=https://keyserver.ubuntu.com/pks/lookup?op=get&search=0x23F3D4EA75716059
#
# That key expired on 2026-09-05, and packages since are signed with its successor,
# 7F38 BBB5 9D06 4DBC B3D8  4D72 5612 B364 6231 3325. dnf imported the old key again and
# refused every gh update with "Import of the key didn't help, wrong key?". GitHub's
# current repo file points at the keyring on its own domain, which holds both; that is
# what install/packaging/github-cli.sh fetches, but nothing re-fetches a repo file that
# is already there.
#
# Only the key line changes, and only when it still names the keyserver: a repo file
# pointed somewhere else was pointed there on purpose.

REPO="/etc/yum.repos.d/gh-cli.repo"
KEYRING="https://cli.github.com/packages/githubcli-archive-keyring.asc"

if [[ ! -f $REPO ]]; then
  echo "  no GitHub CLI repository on this machine"
  exit 0
fi

if ! grep -q '^gpgkey=https://keyserver.ubuntu.com/.*23F3D4EA75716059' "$REPO"; then
  echo "  the GitHub CLI repository already names its current key"
  exit 0
fi

sudo sed -i "s|^gpgkey=.*|gpgkey=$KEYRING|" "$REPO" || exit 1
sudo rpm --import "$KEYRING" || exit 1
echo "  the GitHub CLI repository now takes its key from cli.github.com"

# Prove it, rather than assume: this is the fetch that was failing.
if sudo dnf -q --refresh makecache --repo=gh-cli >/dev/null 2>&1; then
  echo "  the repository fetches cleanly"
else
  echo "  WARNING: the repository still does not fetch; run: sudo dnf makecache --repo=gh-cli" >&2
fi
