#!/usr/bin/env bash

# kubecolor in front of kubectl and oc at the prompt: installed, and the fish snippet that
# does it copied over, since config/ reaches ~/.config only on an install.
command -v kubecolor >/dev/null 2>&1 ||
  "$HOME/.local/share/desktop/bin/desktop-update-releases" kubecolor || true
src="$HOME/.local/share/desktop/config/fish/conf.d/kubecolor.fish"
dst="${XDG_CONFIG_HOME:-$HOME/.config}/fish/conf.d/kubecolor.fish"
if [[ -f $src && ! -e $dst ]]; then
  mkdir -p "${dst%/*}"
  cp "$src" "$dst"
  echo "  kubectl and oc are coloured by kubecolor in new shells"
fi
exit 0
