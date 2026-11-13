#!/usr/bin/env bash

# ocl becomes desktop-cluster: OpenShift, RKE2, Talos and plain Kubernetes clusters, listed in
# ~/.config/desktop/clusters.conf, each with a kubeconfig of its own instead of a context in
# the one ~/.kube/config.
#
# The old ocl had its clusters written into the script (OCL_NAMES) and signed in to them in
# ~/.kube/config, under a context named after each. Both are carried over, so nothing has to
# be signed in to again: each cluster's server goes into clusters.conf, and its context --
# token and all -- into its own kubeconfig. A clusters.conf that is already there is left
# alone. ocl is now a fish function calling desktop-cluster, which fish finds before the old
# script on PATH; the script itself is left where it is.

conf="${XDG_CONFIG_HOME:-$HOME/.config}/desktop/clusters.conf"
store="${XDG_STATE_HOME:-$HOME/.local/state}/desktop/clusters"
new="$HOME/.local/share/desktop/bin/desktop-cluster"

# The old ocl: wherever it is on PATH, as long as it is not already the new one.
old=""
for candidate in "$HOME/.local/bin/ocl" $(type -ap ocl 2>/dev/null); do
  [[ -f $candidate && $(readlink -f "$candidate") != "$(readlink -f "$new")" ]] && { old=$candidate; break; }
done

if [[ ! -e $conf && -n $old ]]; then
  names=$(sed -n 's/^OCL_NAMES=(\(.*\))$/\1/p' "$old" | tr -d "\"'")
  kube=$(command -v kubectl || command -v oc)
  if [[ -n $names ]]; then
    mkdir -p "$(dirname "$conf")" "$store" && chmod 700 "$store"
    {
      echo "# Carried over from $old by desktop-update. See: desktop-cluster --help"
      echo "# name    kind       how to reach it"
      for name in $names; do
        server=""
        [[ -n $kube ]] && server=$("$kube" config view --raw -o json 2>/dev/null | jq -r --arg n "$name" '
          (.contexts[]? | select(.name == $n) | .context.cluster) as $c
          | .clusters[]? | select(.name == $c) | .cluster.server' 2>/dev/null | head -1)
        if [[ -n $server ]]; then
          printf '%-9s openshift  server=%s\n' "$name" "$server"
          if [[ ! -e $store/$name.kubeconfig ]] &&
            "$kube" config view --raw --flatten --minify --context "$name" >"$store/$name.kubeconfig" 2>/dev/null; then
            chmod 600 "$store/$name.kubeconfig"
          else
            rm -f "$store/$name.kubeconfig"
          fi
        else
          printf '# %-7s openshift  server=   (no context called %s in ~/.kube/config to take it from)\n' "$name" "$name"
        fi
      done
    } >"$conf"
    echo "  the clusters in ocl are in $conf now"
  fi
fi

# The fish function that makes ocl desktop-cluster, and the completions for both: config/
# reaches ~/.config only on an install.
src="$HOME/.local/share/desktop/config/fish"
for file in functions/ocl.fish completions/ocl.fish completions/desktop-cluster.fish; do
  [[ -f $src/$file ]] || continue
  mkdir -p "$HOME/.config/fish/$(dirname "$file")"
  cp "$src/$file" "$HOME/.config/fish/$file"
done

# For the Talos clusters it can now reach.
command -v talosctl >/dev/null 2>&1 || "$HOME/.local/share/desktop/bin/desktop-update-releases" talosctl || true
exit 0
