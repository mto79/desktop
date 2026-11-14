#!/usr/bin/env bash

# prefix + K: what prefix + f is for a repository, for a cluster -- pick one, sign in if it
# needs it, and go to a tmux session named after it with a shell and k9s (ocl session).
TMUX_CONF="$HOME/.config/tmux/tmux.conf"
[[ -f $TMUX_CONF ]] || exit 0
grep -q 'desktop-cluster session' "$TMUX_CONF" && exit 0
{
  echo
  echo "# The same for a cluster: pick one, sign in if it needs it, and go to a session named after"
  echo "# it with a shell and k9s on it. K for Kubernetes; see \`ocl session\`."
  echo "bind-key K run-shell \"tmux neww -n cluster 'desktop-cluster session'\""
} >>"$TMUX_CONF"
tmux source-file "$TMUX_CONF" 2>/dev/null || true
echo "  prefix + K opens a session on a cluster"
