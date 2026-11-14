#!/usr/bin/env bash

# prefix + ? lists sixty lines now, in two columns where the terminal is wide enough. The
# popup it opens was a fixed 84 by 48, which cut the end of the list off on a laptop's
# screen; it is sized to the screen instead. Only the line as it was shipped is changed.
TMUX_CONF="$HOME/.config/tmux/tmux.conf"
[[ -f $TMUX_CONF ]] || exit 0
old='bind-key ? display-popup -E -w 84 -h 48 -T " Keys " "desktop-tmux-keys"'
new='bind-key ? display-popup -E -w 96% -h 90% -T " Keys " "desktop-tmux-keys"'
grep -qxF "$old" "$TMUX_CONF" || exit 0
tmp=$(mktemp)
awk -v old="$old" -v new="$new" '$0 == old { print new; next } { print }' "$TMUX_CONF" >"$tmp" && mv "$tmp" "$TMUX_CONF"
tmux source-file "$TMUX_CONF" 2>/dev/null || true
echo "  prefix + ? opens sized to the screen"
