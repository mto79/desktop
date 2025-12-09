#!/usr/bin/env bash

echo "Enabling COPR Repos"

# Array of COPR repos to enable
COPR_REPOS=(
  "solopasha/hyprland" # COPR for USWM and Hyprland packages
  "jdxcode/mise"       # COPR for mise
  "atim/starship"      # COPR for starship
  # "scottames/ghostty"    # COPR for Ghostty
)

# Loop through array and enable each repo
for repo in "${COPR_REPOS[@]}"; do
  echo "Enabling COPR repo: $repo"
  sudo dnf copr enable -y "$repo"
done
