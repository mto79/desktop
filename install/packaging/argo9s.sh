#!/usr/bin/env bash

# argo9s: a k9s-style terminal UI for Argo CD applications. Read-only unless told otherwise.
#
# Not in Fedora, and not from a project with much history: one author, one release, a
# month old when this was written. It is handed a kubeconfig or an Argo CD token, so it is
# installed the careful way -- one exact version, and the archive's checksum written down
# here rather than fetched alongside it. A release that is quietly replaced then fails to
# install instead of installing; a new version is a deliberate edit of these two lines,
# made after looking at what changed.
#
# Into ~/.local/bin, which needs no sudo and is where the other single binaries live.

ARGO9S_VERSION="0.1.0"
ARGO9S_SHA256="560bc0e4bb8f26c5dc8f9b8d95a3323b398f0340ae5d01c5bed400abd9712e7d"
ARGO9S_TARGET="${ARGO9S_TARGET:-$HOME/.local/bin/argo9s}"

if [[ $(uname -m) != x86_64 ]]; then
  # The checksum above is the amd64 archive's.
  echo "argo9s: only set up for x86_64 here, skipping"
elif [[ -x $ARGO9S_TARGET && $("$ARGO9S_TARGET" --version 2>/dev/null) == "argo9s $ARGO9S_VERSION" ]]; then
  echo "argo9s $ARGO9S_VERSION is already installed"
else
  echo "Installing argo9s $ARGO9S_VERSION"
  argo9s_work=$(mktemp -d)
  argo9s_archive="argo9s_${ARGO9S_VERSION}_linux_amd64.tar.gz"
  if curl -fsSL --max-time 300 -o "$argo9s_work/$argo9s_archive" \
    "https://github.com/vvrnv/argo9s/releases/download/v$ARGO9S_VERSION/$argo9s_archive" &&
    echo "$ARGO9S_SHA256  $argo9s_work/$argo9s_archive" | sha256sum --check --quiet &&
    tar -xzf "$argo9s_work/$argo9s_archive" -C "$argo9s_work" argo9s; then
    mkdir -p "$(dirname "$ARGO9S_TARGET")"
    install -m 0755 "$argo9s_work/argo9s" "$ARGO9S_TARGET"
    echo "argo9s $ARGO9S_VERSION installed"
  else
    # Not fatal to the install it is part of: a desktop without argo9s is still a desktop.
    echo "argo9s: download failed or the checksum did not match; nothing installed" >&2
  fi
  rm -rf "$argo9s_work"
fi
