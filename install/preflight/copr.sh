#!/usr/bin/env bash

echo "Enabling COPR Repos"

# Array of COPR repos to enable
COPR_REPOS=(
  # NOTE: solopasha builds for rawhide only since Nov 2025 -- the fedora-43 chroot is
  # gone from the backend, so this repo resolves to nothing here and every hypr* package
  # already installed from it is frozen. Left enabled because skip_if_unavailable makes
  # it harmless, but the Hyprland stack needs a new source before the next Fedora bump.
  "solopasha/hyprland"         # COPR for USWM and Hyprland packages
  "jdxcode/mise"               # COPR for mise
  "atim/starship"              # COPR for starship
  "lihaohong/yazi"             # COPR for yazi
  "scottames/ghostty"          # COPR for Ghostty
  "wezfurlong/wezterm-nightly" # COPR for wezterm
  "kylegospo/grub-btrfs"       # COPR for grub-btrfs
)

# Loop through array and enable each repo
for repo in "${COPR_REPOS[@]}"; do
  echo "Enabling COPR repo: $repo"
  sudo dnf copr enable -y "$repo"
done

# hyprpolkitagent is not packaged in Fedora and solopasha no longer builds it here, but
# it is what default/hypr/autostart.conf enables -- without it nothing draws a polkit
# prompt and KeePassXC's fingerprint unlock is asked of an agent that is not there.
#
# This project also ships Hyprland itself, several releases ahead of what is installed,
# and an hyprland-guiutils that links against libhyprutils.so.13 while the running
# compositor needs .so.9; letting either in would leave a session that will not start.
# includepkgs is what holds the repo to the two packages we actually came for.
echo "Enabling COPR repo: hermitfeather/hyprland-dev (hyprpolkitagent only)"
sudo dnf copr enable -y hermitfeather/hyprland-dev
sudo dnf config-manager setopt \
  "copr:copr.fedorainfracloud.org:hermitfeather:hyprland-dev.includepkgs=hyprpolkitagent,hyprland-qt-support"
