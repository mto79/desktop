#!/usr/bin/env bash

# kubeseal: encrypts a Secret into a SealedSecret that only the cluster's controller can
# open, so it can be committed to Git. The client half of Bitnami's sealed-secrets.
#
# Not in Fedora. It is handed secrets in the clear and a kubeconfig, so it is installed the
# careful way, as argo9s is: one exact version, and the archive's checksum written down
# here rather than fetched alongside it. A release that is quietly replaced then fails to
# install instead of installing; a new version is a deliberate edit of these two lines.
# 0.40.0 rather than the newest: 0.41.0 and 0.41.1 came out the same day this was
# written, the second a fix for the first, and neither had been out long enough to trust.
#
# Into ~/.local/bin, which needs no sudo and is where the other single binaries live.

KUBESEAL_VERSION="0.40.0"
KUBESEAL_SHA256="9314c35916646e9d59c8f06b1314574b4e79c4d76f079433607ed7b697bb5eb7"
KUBESEAL_TARGET="${KUBESEAL_TARGET:-$HOME/.local/bin/kubeseal}"

if [[ $(uname -m) != x86_64 ]]; then
  # The checksum above is the amd64 archive's.
  echo "kubeseal: only set up for x86_64 here, skipping"
elif [[ -x $KUBESEAL_TARGET && $("$KUBESEAL_TARGET" --version 2>/dev/null) == "kubeseal version: $KUBESEAL_VERSION" ]]; then
  echo "kubeseal $KUBESEAL_VERSION is already installed"
else
  echo "Installing kubeseal $KUBESEAL_VERSION"
  kubeseal_work=$(mktemp -d)
  kubeseal_archive="kubeseal-${KUBESEAL_VERSION}-linux-amd64.tar.gz"
  if curl -fsSL --max-time 300 -o "$kubeseal_work/$kubeseal_archive" \
    "https://github.com/bitnami-labs/sealed-secrets/releases/download/v$KUBESEAL_VERSION/$kubeseal_archive" &&
    echo "$KUBESEAL_SHA256  $kubeseal_work/$kubeseal_archive" | sha256sum --check --quiet &&
    tar -xzf "$kubeseal_work/$kubeseal_archive" -C "$kubeseal_work" kubeseal; then
    mkdir -p "$(dirname "$KUBESEAL_TARGET")"
    install -m 0755 "$kubeseal_work/kubeseal" "$KUBESEAL_TARGET"
    echo "kubeseal $KUBESEAL_VERSION installed"
  else
    # Not fatal to the install it is part of: a desktop without kubeseal is still a desktop.
    echo "kubeseal: download failed or the checksum did not match; nothing installed" >&2
  fi
  rm -rf "$kubeseal_work"
fi
