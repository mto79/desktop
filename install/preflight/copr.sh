#!/usr/bin/env bash

echo "Enabling COPR Repos"

# Array of COPR repos to enable
COPR_REPOS=(
  "jdxcode/mise"               # COPR for mise
  "atim/starship"              # COPR for starship
  "lihaohong/yazi"             # COPR for yazi
  "scottames/ghostty"          # COPR for Ghostty
  "kylegospo/grub-btrfs"       # COPR for grub-btrfs
  "errornointernet/quickshell" # COPR for Quickshell (not in Fedora repos)
)

# Loop through array and enable each repo
for repo in "${COPR_REPOS[@]}"; do
  echo "Enabling COPR repo: $repo"
  sudo dnf copr enable -y "$repo"
done

# The Hyprland stack. solopasha stopped building for released Fedora in Nov 2025, which
# left the compositor frozen at 0.51.1 with nothing to upgrade to.
#
# mineiro rather than the more obvious hermitfeather, for a reason worth recording:
# hermitfeather ships only the newest build of each library, so its own hyprland cannot
# be installed -- 0.55.2 wants libaquamarine.so.10 and libhyprutils.so.12 while the repo
# carries only aquamarine 0.14.0 and hyprutils 0.14.1. Its f44 branch is fine; its f43
# branch is not. mineiro keeps every library version alongside every compositor version,
# so each hyprland finds the sonames it was built against. It also builds satty, which
# hermitfeather does not.
#
# Pinned with includepkgs. The repo carries far more than this desktop wants, and a dev
# repo quietly replacing something unrelated is exactly the failure this cannot absorb.
#
# The list is a dependency closure, not a wishlist: a package missing from it is
# "filtered out by exclude filtering" and dnf reports only that it cannot install the
# compositor, without naming the pin as the cause. hyprwire was the one that bit --
# Hyprland grew a dependency on it at 0.53. Derive the list with repoquery --requires
# rather than guessing when the stack moves again.
HYPR_PACKAGES=(
  aquamarine hypridle hyprcursor hyprgraphics hyprland hyprland-guiutils
  hyprland-qt-support hyprland-uwsm hyprlang hyprlock hyprpicker hyprpolkitagent
  hyprshot hyprsunset hyprtoolkit hyprutils hyprwire satty uwsm
  xdg-desktop-portal-hyprland
)

echo "Enabling COPR repo: mineiro/hyprland (the Hyprland stack)"
sudo dnf copr enable -y mineiro/hyprland
# setopt writes to /etc/dnf/repos.override.d/99-config_manager.repo, not to the .repo
# file copr enable manages, so the two do not fight and the pin survives a re-enable.
# It still has to come second: the repo must exist before it can be configured.
sudo dnf config-manager setopt \
  "copr:copr.fedorainfracloud.org:mineiro:hyprland.includepkgs=$(
    IFS=,; echo "${HYPR_PACKAGES[*]}")"
