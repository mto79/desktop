#!/usr/bin/env bash

# tea: the Gitea command line, which works against Forgejo -- Codeberg included -- as
# well. desktop-reviews asks it for the pull requests waiting for you, as it asks glab and
# gh, on every instance `tea login add` has been run for.
#
# Not in Fedora. It holds a token for each instance, so it is installed the careful way,
# as argo9s is: one exact version, and the binary's checksum written down here rather than
# fetched alongside it. A new version is a deliberate edit of these two lines.
#
# Into ~/.local/bin, which needs no sudo and is where the other single binaries live.

TEA_VERSION="0.16.0"
TEA_SHA256="9c142c8a0b31485eea2387031c1c404f12b7141075eb4ffbd7ced49441590636"
TEA_TARGET="${TEA_TARGET:-$HOME/.local/bin/tea}"

if [[ $(uname -m) != x86_64 ]]; then
  # The checksum above is the amd64 binary's.
  echo "tea: only set up for x86_64 here, skipping"
elif [[ -x $TEA_TARGET && $("$TEA_TARGET" --version 2>/dev/null) == *"$TEA_VERSION"* ]]; then
  echo "tea $TEA_VERSION is already installed"
else
  echo "Installing tea $TEA_VERSION"
  tea_work=$(mktemp -d)
  tea_binary="tea-$TEA_VERSION-linux-amd64"
  if curl -fsSL --max-time 300 -o "$tea_work/$tea_binary" "https://dl.gitea.com/tea/$TEA_VERSION/$tea_binary" &&
    echo "$TEA_SHA256  $tea_work/$tea_binary" | sha256sum --check --quiet; then
    mkdir -p "$(dirname "$TEA_TARGET")"
    install -m 0755 "$tea_work/$tea_binary" "$TEA_TARGET"
    echo "tea $TEA_VERSION installed"
  else
    # Not fatal to the install it is part of: without tea, Forgejo is simply not asked.
    echo "tea: download failed or the checksum did not match; nothing installed" >&2
  fi
  rm -rf "$tea_work"
fi
