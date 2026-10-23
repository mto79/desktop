#!/usr/bin/env bash

# Hyprland reads hyprland.lua from the next login. 0.57 reads nothing else, and the scripts
# and the bar already speak only the Lua dispatchers -- which this session, still on
# hyprland.conf, refuses. So workspace switching from the bar, the launcher's window jumps
# and the screen-off on idle stay broken until you log out and back in.
#
# config/ reaches ~/.config only through the installer, so the Lua files are placed here.
# None is overwritten: one already there is yours. monitors.lua and workspaces.lua start
# empty and are written by their scripts once the Lua session is up -- the layout is
# applied again at that first login, with a reload and its notification.

HYPR="$HOME/.config/hypr"
REPO="$HOME/.local/share/desktop/config"

for lua in "$REPO"/hypr/*.lua; do
  [[ -e $HYPR/$(basename "$lua") ]] || cp "$lua" "$HYPR/" || exit 1
done

# A .conf that is not the repository's own is a change of yours, and nothing carries it
# into the .lua beside it. Said rather than converted: hyprlang is not worth parsing for
# the handful of lines that will ever be in here.
for conf in autostart bindings envs input looknfeel windows; do
  if [[ -f $HYPR/$conf.conf ]] && ! cmp -s "$HYPR/$conf.conf" "$REPO/hypr/$conf.conf"; then
    echo "  ~/.config/hypr/$conf.conf has changes of yours: copy them into $conf.lua"
  fi
done

# hypridle keeps hyprlang, but what it runs is told to the Lua session. Not restarted here,
# where the new commands would be refused: the next login starts it again.
if [[ -f $HYPR/hypridle.conf ]]; then
  sed -i "s/hyprctl dispatch dpms on/hyprctl dispatch 'hl.dsp.dpms({ action = \"on\" })'/g;
    s/hyprctl dispatch dpms off/hyprctl dispatch 'hl.dsp.dpms({ action = \"off\" })'/g" \
    "$HYPR/hypridle.conf" || exit 1
fi

WAYBAR="$HOME/.config/waybar/config.jsonc"
if [[ -f $WAYBAR ]]; then
  sed -i "s/\"hyprctl dispatch workspace \(e[-+]1\)\"/\"hyprctl dispatch 'hl.dsp.focus({ workspace = \\\\\"\1\\\\\" })'\"/" \
    "$WAYBAR" || exit 1
fi

echo "  Hyprland reads hyprland.lua from the next login: log out and back in now"
