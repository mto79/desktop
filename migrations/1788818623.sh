#!/usr/bin/env bash

# Ghostty is the only terminal now, so TUI shortcuts written before that still launch
# through alacritty and would simply stop working once it is uninstalled.
#
# desktop-tui-install writes new entries with --title, since ghostty cannot set a
# Wayland app id and the floating window rules match the title instead. This rewrites
# the entries already on disk the same way, keeping the class name as the title so the
# existing rules still match them.

shopt -s nullglob

changed=0
for file in ~/.local/share/applications/*.desktop; do
  grep -qE '^Exec=(alacritty|wezterm)\b' "$file" || continue

  # Both spellings appeared over the years: `--class X` and `--class=X`.
  sed -i -E 's/^Exec=(alacritty|wezterm) +--class[ =]([^ ]+) +-e /Exec=ghostty --title=\2 -e /' "$file"
  # An entry with no class at all still has to stop naming a terminal that is gone.
  sed -i -E 's/^Exec=(alacritty|wezterm) +-e /Exec=ghostty -e /' "$file"

  echo "  rewrote $(basename "$file")"
  changed=1
done

if ((changed)); then
  update-desktop-database ~/.local/share/applications 2>/dev/null || true
else
  echo "  no desktop entries needed rewriting"
fi
