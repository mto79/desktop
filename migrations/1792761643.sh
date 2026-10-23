#!/usr/bin/env bash

# tmux.conf no longer loads TPM. It ran at the end of every config load to manage two
# plugins that were never fetched: tmux-resurrect, which desktop-tmux-restore does in its
# own way, and tmux-yank, which set-clipboard on already covers. The copy of TPM the
# installer placed under ~/.config/tmux/plugins is the repository's, and goes with it.

PLUGINS="$HOME/.config/tmux/plugins"

[[ -f $PLUGINS/tpm/tpm ]] && rm -rf "$PLUGINS/tpm"
# Left in place when there is anything else in it: that would be yours.
[[ -d $PLUGINS ]] && rmdir "$PLUGINS" 2>/dev/null
exit 0
