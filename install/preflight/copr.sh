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

# The Hyprland stack lives here now. solopasha, which built it until Nov 2025, has no
# chroot for any released Fedora any more -- so this is not a preference, it is the only
# maintained source. It carries Hyprland itself, which is the point: the compositor was
# frozen at 0.51.1 with no security or bug fixes.
#
# Still pinned with includepkgs rather than left open. The repo also ships packages that
# would shadow Fedora's own (hyprlang, hyprutils and friends exist in both), and an
# unpinned dev repo deciding to replace something unrelated is exactly the failure this
# desktop cannot absorb. Add a name here deliberately when it is needed.
HYPR_PACKAGES=(
  aquamarine hypridle hyprcursor hyprgraphics hyprland hyprland-guiutils
  hyprland-qt-support hyprland-uwsm hyprlang hyprlock hyprpicker hyprpolkitagent
  hyprshot hyprsunset hyprtoolkit hyprutils uwsm xdg-desktop-portal-hyprland
)

echo "Enabling COPR repo: hermitfeather/hyprland-dev (the Hyprland stack)"
sudo dnf copr enable -y hermitfeather/hyprland-dev
sudo dnf config-manager setopt \
  "copr:copr.fedorainfracloud.org:hermitfeather:hyprland-dev.includepkgs=$(
    IFS=,; echo "${HYPR_PACKAGES[*]}")"

# satty is the one thing hermitfeather does not build. It is the screenshot annotator
# desktop-cmd-screenshot pipes into, so without it every screenshot fails silently.
echo "Enabling COPR repo: mineiro/satty"
sudo dnf copr enable -y mineiro/satty
sudo dnf config-manager setopt \
  "copr:copr.fedorainfracloud.org:mineiro:satty.includepkgs=satty"
