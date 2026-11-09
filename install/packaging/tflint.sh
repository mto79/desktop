#!/usr/bin/env bash

# tflint: a linter for Terraform and OpenTofu, catching what `validate` lets through —
# invalid instance types, unused declarations, deprecated syntax.
#
# Not in Fedora. Installed the way kubeseal is: one exact version, and the archive's
# checksum written down here rather than fetched alongside it, so a release that is quietly
# replaced fails to install instead of installing. A new version is a deliberate edit of
# these two lines. Its install script is avoided on purpose: it fetches whatever is latest.
#
# Into ~/.local/bin, which needs no sudo and is where the other single binaries live.

TFLINT_VERSION="0.65.0"
TFLINT_SHA256="d4c545ed2e29d6338604b586f34f544f380f70f243aa72f7b484713835eaec61"
TFLINT_TARGET="${TFLINT_TARGET:-$HOME/.local/bin/tflint}"

if [[ $(uname -m) != x86_64 ]]; then
  # The checksum above is the amd64 archive's.
  echo "tflint: only set up for x86_64 here, skipping"
elif [[ -x $TFLINT_TARGET && $("$TFLINT_TARGET" --version 2>/dev/null | head -n1) == "TFLint version $TFLINT_VERSION" ]]; then
  echo "tflint $TFLINT_VERSION is already installed"
else
  echo "Installing tflint $TFLINT_VERSION"
  tflint_work=$(mktemp -d)
  tflint_archive="tflint_linux_amd64.zip"
  if curl -fsSL --max-time 300 -o "$tflint_work/$tflint_archive" \
    "https://github.com/terraform-linters/tflint/releases/download/v$TFLINT_VERSION/$tflint_archive" &&
    echo "$TFLINT_SHA256  $tflint_work/$tflint_archive" | sha256sum --check --quiet &&
    unzip -q "$tflint_work/$tflint_archive" tflint -d "$tflint_work"; then
    mkdir -p "$(dirname "$TFLINT_TARGET")"
    install -m 0755 "$tflint_work/tflint" "$TFLINT_TARGET"
    echo "tflint $TFLINT_VERSION installed"
  else
    # Not fatal to the install it is part of: a desktop without tflint is still a desktop.
    echo "tflint: download failed or the checksum did not match; nothing installed" >&2
  fi
  rm -rf "$tflint_work"
fi
