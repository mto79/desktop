#!/usr/bin/env bash
#
# nvidia.sh — NVIDIA driver and CUDA toolkit, from NVIDIA's own repository.
#
# The previous version of this script ran `dnf install cuda-drivers` without ever
# adding the repository that provides it, so it only ever worked on a machine where
# somebody had already added that repo by hand -- which is to say, never on a clean
# install. Adding the repo is most of what this file is for.
#
# Fedora's own repositories do not carry the NVIDIA driver at all, and rpmfusion's
# akmod build is a different driver stack from the one installed here; mixing them is
# how you end up with two drivers fighting over one card. This machine is on NVIDIA's
# packages, so this script keeps it there.
#
# Safe to re-run: every step checks before it changes anything.

set -euo pipefail

# Sourced by packaging/all.sh on whatever machine is being built, so a box with no
# NVIDIA card has to fall straight through rather than fail the whole install.
if ! lspci -d 10de:: -n 2>/dev/null | grep -qE ' 03[0-9a-f]{2}: '; then
  echo "No NVIDIA GPU found, skipping the driver"
  return 0 2>/dev/null || exit 0
fi

RELEASE=$(rpm -E %fedora)
REPO_BASE="https://developer.download.nvidia.com/compute/cuda/repos/fedora${RELEASE}/x86_64"
REPO_FILE="/etc/yum.repos.d/cuda-fedora-nvidia.repo"

# NVIDIA publishes a repository per Fedora release, and lags a new one by weeks or
# months. Checking first turns "no match for argument cuda-drivers" -- which reads like
# a broken script -- into a sentence that says what is actually wrong.
echo "Checking NVIDIA's repository for Fedora ${RELEASE}..."
if ! curl -fsSL -o /dev/null "${REPO_BASE}/repodata/repomd.xml"; then
  echo "NVIDIA has published no CUDA repository for Fedora ${RELEASE} yet." >&2
  echo "Nothing was changed. Check ${REPO_BASE} and re-run when it appears." >&2
  exit 1
fi

# NVIDIA rotates the repository signing key between Fedora releases -- fedora43 carries
# only 1940C73E.pub and fedora44 only 73CD9B30.pub -- and signs each release's packages
# with that release's key. So the name cannot be written into a $releasever URL the way
# the baseurl can, and reading it out of the repository is only half the job.
#
# The other half: this repository has to trust the *next* release's key as well as the
# current one. `dnf system-upgrade` verifies fc(N+1) packages while the machine is still
# running N, so a gpgkey naming only the current release fails the offline transaction
# with "Import of the key didn't help, wrong key?" -- and it fails after the multi-
# gigabyte download, which is a late and expensive place to learn it. Trusting the next
# key in advance is what makes the upgrade work unattended.
resolve_key() {
  curl -fsSL "$1/" 2>/dev/null | grep -oE '[A-Za-z0-9._-]+\.pub' | sort -u | head -1
}

echo "Resolving NVIDIA's signing keys..."
REPO_KEYS=""
for rel in "$RELEASE" "$((RELEASE + 1))"; do
  key_base="https://developer.download.nvidia.com/compute/cuda/repos/fedora${rel}/x86_64"
  key=$(resolve_key "$key_base")
  if [[ -n "$key" ]]; then
    echo "  Fedora ${rel}: ${key}"
    REPO_KEYS="${REPO_KEYS:+$REPO_KEYS }${key_base}/${key}"
  else
    # Not an error: NVIDIA lags a new Fedora by weeks, so the next release usually has
    # no repository yet. Re-run this script once it appears and before upgrading.
    echo "  Fedora ${rel}: nothing published yet"
  fi
done

if [[ -z "$REPO_KEYS" ]]; then
  echo "No signing key found for Fedora ${RELEASE}." >&2
  echo "Nothing was changed. Check ${REPO_BASE}/ and re-run." >&2
  exit 1
fi

# A repository added by hand before this script existed sits in a differently named file
# with the release number baked into its baseurl. Left in place it survives a Fedora
# upgrade still pointing at the old release, quietly shadowing the one written below --
# two repositories for one thing, one of them permanently stale. The glob cannot match
# this script's own file, which carries no digits.
for stale in /etc/yum.repos.d/cuda-fedora[0-9]*.repo; do
  [[ -e "$stale" ]] || continue
  echo "  removing stale hand-added repository $(basename "$stale")"
  sudo rm -f "$stale"
done

# $releasever rather than the number resolved above, so the repository follows the next
# Fedora upgrade instead of pinning this machine to the release it was installed on.
# The check above is what keeps that from silently breaking: dnf is deliberately left
# to fail loudly on a missing repo, since a driver quietly not updating is worse.
#
# The keys are the exception, being names rather than paths. Both the current release's
# and the next one's are listed, so an upgrade verifies; re-run this script afterwards
# to pick up the release after that.
sudo tee "$REPO_FILE" >/dev/null <<EOF
[cuda-fedora-nvidia]
name=NVIDIA CUDA for Fedora \$releasever
baseurl=https://developer.download.nvidia.com/compute/cuda/repos/fedora\$releasever/x86_64
enabled=1
gpgcheck=1
gpgkey=${REPO_KEYS}
EOF

# The module is built by DKMS against the running kernel, so its headers have to be
# present before the driver package is unpacked. kernel-devel-matched keeps them in step
# with the kernel across later updates.
sudo dnf install -y dkms kernel-devel-matched "kernel-devel-$(uname -r)"

# cuda-drivers pulls the driver and kmod-nvidia-latest-dkms; cuda-toolkit is the compute
# side (nvcc and friends), which is the reason this machine has NVIDIA's packages rather
# than rpmfusion's in the first place.
sudo dnf install -y cuda-drivers cuda-toolkit

# nouveau and nova-core both bind this card and must be out of the way before the
# initramfs is built. nova-core is the newer Rust driver, present from kernel 6.19 --
# blacklisting only nouveau, as the old script did, is no longer enough.
sudo tee /etc/modprobe.d/blacklist-nouveau.conf >/dev/null <<'EOF'
blacklist nouveau
options nouveau modeset=0
blacklist nova_core
EOF

# The same two, early enough to matter: a module already bound in the initramfs cannot
# be displaced later. grubby covers the kernels already installed; /etc/default/grub is
# what every future one inherits.
CMDLINE_ARGS="rd.driver.blacklist=nouveau rd.driver.blacklist=nova-core"
for arg in $CMDLINE_ARGS; do
  grep -q -- "$arg" /etc/default/grub || sudo sed -i "s|^GRUB_CMDLINE_LINUX=\"|GRUB_CMDLINE_LINUX=\"$arg |" /etc/default/grub
done
sudo grubby --update-kernel=ALL --args="$CMDLINE_ARGS"

# Rebuild every initramfs, not just the running kernel's: a machine that boots an older
# kernel after this would otherwise still come up on nouveau.
sudo dracut --force --regenerate-all

# Keeps the discrete GPU powered rather than letting PCI runtime power management put it
# to sleep. Carried over from the previous script and kept deliberately: on this laptop
# the live value reads back as "auto" anyway -- either nvidia-powerd overrides it or the
# rule never matches -- so removing it is probably harmless, but suspend and resume bugs
# on a hybrid laptop are miserable to debug and this is not the commit to find out in.
NVIDIA_PCI_ID=$(lspci -n -d 10de: | awk 'NR==1 {split($3, a, ":"); print a[2]}')
if [[ -n "$NVIDIA_PCI_ID" ]]; then
  echo "ACTION==\"add\", SUBSYSTEM==\"pci\", ATTR{vendor}==\"0x10de\", ATTR{device}==\"0x${NVIDIA_PCI_ID}\", ATTR{power/control}=\"on\"" |
    sudo tee /etc/udev/rules.d/99-nvidia-power.rules >/dev/null
fi

# The module is built at install time, so a failure here is visible now rather than at
# the next boot, when the desktop comes up without a driver and nothing says why.
echo ""
echo "DKMS status:"
dkms status | grep -i nvidia || echo "  no nvidia module built -- check 'dkms status' before rebooting"

echo ""
echo "NVIDIA driver and CUDA toolkit installed. Reboot to load the module."
