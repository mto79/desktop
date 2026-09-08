#!/usr/bin/env bash

# This machine still carries the CUDA repository somebody added by hand long before
# install/packaging/nvidia.sh existed: cuda-fedora43.repo, with the release number baked
# into its baseurl and into its gpgkey. nvidia.sh writes the same repository under a
# different name, cuda-fedora-nvidia.repo, so running it would leave both files -- and
# the hand-added one would go on pointing at fedora43 through the upgrade to 44, where
# it serves fc43 packages into an fc44 transaction.
#
# The key has to be resolved rather than copied: NVIDIA rotates it per release, fedora43
# carrying only 1940C73E.pub and fedora44 only 73CD9B30.pub. That is also why the
# baseurl below follows $releasever but the gpgkey does not.
#
# Deliberately narrow. It fixes the repository and nothing else -- no driver install, no
# initramfs rebuild. Run install/packaging/nvidia.sh for those.

shopt -s nullglob

stale=(/etc/yum.repos.d/cuda-fedora[0-9]*.repo)

if ((${#stale[@]} == 0)); then
  echo "  no hand-added CUDA repository to replace"
  exit 0
fi

RELEASE=$(rpm -E %fedora)
REPO_BASE="https://developer.download.nvidia.com/compute/cuda/repos/fedora${RELEASE}/x86_64"
REPO_FILE="/etc/yum.repos.d/cuda-fedora-nvidia.repo"

# Resolve the key before touching anything, so a repository NVIDIA has not published yet
# leaves the working one in place rather than deleting it and writing nothing.
REPO_KEY=$(curl -fsSL "${REPO_BASE}/" | grep -oE '[A-Za-z0-9._-]+\.pub' | sort -u | head -1)
if [[ -z "$REPO_KEY" ]]; then
  echo "  no signing key found at ${REPO_BASE}/ -- leaving ${stale[0]} alone" >&2
  exit 1
fi

sudo tee "$REPO_FILE" >/dev/null <<EOF
[cuda-fedora-nvidia]
name=NVIDIA CUDA for Fedora \$releasever
baseurl=https://developer.download.nvidia.com/compute/cuda/repos/fedora\$releasever/x86_64
enabled=1
gpgcheck=1
gpgkey=${REPO_BASE}/${REPO_KEY}
EOF
echo "  wrote $(basename "$REPO_FILE") (key ${REPO_KEY})"

for file in "${stale[@]}"; do
  sudo rm -f "$file"
  echo "  removed $(basename "$file")"
done
