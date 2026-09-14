#!/usr/bin/env bash

# The OpenTofu repository file on machines built before install/packaging/opentofu.sh was
# corrected. Upstream's snippet pins
#
#   sslcacert=/etc/pki/tls/certs/ca-bundle.crt
#
# which Fedora no longer ships -- the bundle lives under /etc/pki/ca-trust/extracted/pem
# and that legacy path is not owned by any package. Every fetch from the repo then dies
# inside curl with "Problem with the SSL CA cert (path? access rights?)", which reads as
# a broken system trust store when the trust store is perfectly fine; only this one repo
# asked for a file that is not there.
#
# packaging/opentofu.sh writes the file without the ssl lines now, but nothing rewrites a
# file that already exists, so a machine that installed tofu earlier keeps the broken
# copy for good. Dropping the lines verifies against the system trust store, which is
# where that path pointed anyway, and cannot break again if the bundle moves.

REPO="/etc/yum.repos.d/opentofu.repo"

if [[ ! -f $REPO ]]; then
  echo "  no OpenTofu repository on this machine"
  exit 0
fi

if ! grep -qE '^ssl(verify|cacert)=' "$REPO"; then
  echo "  the OpenTofu repository already verifies against the system trust store"
  exit 0
fi

sudo sed -i -E '/^ssl(verify|cacert)=/d' "$REPO" || exit 1
echo "  dropped the pinned CA path from $REPO"

# Prove it, rather than assume: this is the fetch that was failing.
if sudo dnf -q --refresh makecache --repo=opentofu >/dev/null 2>&1; then
  echo "  the repository fetches cleanly again"
else
  echo "  WARNING: the repository still does not fetch; run: sudo dnf makecache --repo=opentofu" >&2
fi
