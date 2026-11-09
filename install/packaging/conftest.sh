#!/usr/bin/env bash

# conftest: tests structured configuration -- Kubernetes manifests, Terraform and OpenTofu
# plans, Dockerfiles -- against policies written in Rego, the language of Open Policy Agent.
#
# Not in Fedora. Installed the way tflint and kubeseal are: one exact version, and the
# archive's checksum written down here rather than trusted from the checksums.txt beside
# it, so a release that is quietly replaced fails to install instead of installing. A new
# version is a deliberate edit of these two lines; desktop-update-pinned says when there is one.
#
# Into ~/.local/bin, which needs no sudo and is where the other single binaries live.

CONFTEST_VERSION="0.71.1"
CONFTEST_SHA256="c3f6b2a753bd56e377a1e51a95ae3e057f926f2e9139f7d5b5dfbbaf810f7985"
CONFTEST_TARGET="${CONFTEST_TARGET:-$HOME/.local/bin/conftest}"

if [[ $(uname -m) != x86_64 ]]; then
  # The checksum above is the x86_64 archive's.
  echo "conftest: only set up for x86_64 here, skipping"
elif [[ -x $CONFTEST_TARGET && $("$CONFTEST_TARGET" --version 2>/dev/null | head -n1) == "Conftest: $CONFTEST_VERSION" ]]; then
  echo "conftest $CONFTEST_VERSION is already installed"
else
  echo "Installing conftest $CONFTEST_VERSION"
  conftest_work=$(mktemp -d)
  conftest_archive="conftest_${CONFTEST_VERSION}_Linux_x86_64.tar.gz"
  if curl -fsSL --max-time 300 -o "$conftest_work/$conftest_archive" \
    "https://github.com/open-policy-agent/conftest/releases/download/v$CONFTEST_VERSION/$conftest_archive" &&
    echo "$CONFTEST_SHA256  $conftest_work/$conftest_archive" | sha256sum --check --quiet &&
    tar -xzf "$conftest_work/$conftest_archive" -C "$conftest_work" conftest; then
    mkdir -p "$(dirname "$CONFTEST_TARGET")"
    install -m 0755 "$conftest_work/conftest" "$CONFTEST_TARGET"
    echo "conftest $CONFTEST_VERSION installed"
  else
    # Not fatal to the install it is part of: a desktop without conftest is still a desktop.
    echo "conftest: download failed or the checksum did not match; nothing installed" >&2
  fi
  rm -rf "$conftest_work"
fi
