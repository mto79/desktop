#!/usr/bin/env bash

# k9s in the desktop theme's colours, like the tmux and argo9s around it in a cluster
# session: each theme has a k9s.yaml, linked as the skin k9s's config names.
mkdir -p ~/.config/k9s/skins
ln -snf ~/.config/desktop/current/theme/k9s.yaml ~/.config/k9s/skins/desktop.yaml
if [[ ! -s ~/.config/k9s/config.yaml ]]; then
  printf 'k9s:\n  ui:\n    skin: desktop\n' >~/.config/k9s/config.yaml
elif ! grep -qE '^    skin:' ~/.config/k9s/config.yaml; then
  sed -i '0,/^  ui:$/s//  ui:\n    skin: desktop/' ~/.config/k9s/config.yaml
fi
