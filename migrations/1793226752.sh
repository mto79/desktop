#!/usr/bin/env bash

# NVIDIA's packages only, for the NVIDIA driver. RPM Fusion nonfree, enabled here for
# intel-media-driver, carries nvidia-modprobe, nvidia-persistenced and nvidia-settings
# under the same names and epoch, a point release ahead of NVIDIA's repository. dnf
# tried to upgrade those three from it, NVIDIA's nvidia-driver-cuda, nvidia-kmod-common
# and nvidia-open require them at exactly their own version, and every update ended in
# three "cannot install both" problems. install/packaging/nvidia.sh now excludes them
# from RPM Fusion on a new install; this does the same on a machine that has both.

[[ -f /etc/yum.repos.d/cuda-fedora-nvidia.repo ]] || exit 0

for repo in $(dnf repolist --all 2>/dev/null | awk '$1 ~ /^rpmfusion-nonfree/ {print $1}'); do
  sudo dnf config-manager setopt "${repo}.excludepkgs=*nvidia*" || exit 1
done
exit 0
