#!/usr/bin/env bash

# The CUDA repository trusted only the running release's NVIDIA signing key, and NVIDIA
# uses a different key per Fedora release. `dnf system-upgrade download` therefore
# downloaded all 7.6 GiB, then failed the offline transaction it runs at the end:
#
#   OpenPGP check for package "nvidia-driver-common-3:610.57.04-1.fc44.x86_64"
#   ... has failed: Import of the key didn't help, wrong key?
#
# The fc44 packages are signed with fedora44's key while the machine is still on 43, so
# the repository has to trust the next release's key *before* the upgrade, not after.
# Waiting until afterwards is impossible: the verification is what blocks the upgrade.
#
# Rewrites only the gpgkey line, leaving the rest of the file alone, and imports the
# keys so an already-downloaded transaction can be retried without re-fetching it.

set -uo pipefail

REPO_FILE=/etc/yum.repos.d/cuda-fedora-nvidia.repo

if [[ ! -f $REPO_FILE ]]; then
  echo "  no CUDA repository on this machine, nothing to do"
  exit 0
fi

RELEASE=$(rpm -E %fedora)

resolve_key() {
  curl -fsSL "$1/" 2>/dev/null | grep -oE '[A-Za-z0-9._-]+\.pub' | sort -u | head -1
}

keys=""
for rel in "$RELEASE" "$((RELEASE + 1))"; do
  base="https://developer.download.nvidia.com/compute/cuda/repos/fedora${rel}/x86_64"
  key=$(resolve_key "$base")
  if [[ -n $key ]]; then
    echo "  Fedora ${rel}: ${key}"
    keys="${keys:+$keys }${base}/${key}"
  else
    echo "  Fedora ${rel}: nothing published yet"
  fi
done

if [[ -z $keys ]]; then
  echo "  no signing keys resolved -- leaving $REPO_FILE alone" >&2
  exit 1
fi

# Only the gpgkey line: the baseurl already follows $releasever and must stay that way.
sudo sed -i "s|^gpgkey=.*|gpgkey=${keys}|" "$REPO_FILE"
echo "  updated gpgkey in $(basename "$REPO_FILE")"

# rpm keeps its own keyring, and a transaction already staged for the offline upgrade is
# verified against that. Importing here means the retry needs no second download.
for url in $keys; do
  sudo rpm --import "$url" && echo "  imported $(basename "$url")"
done
