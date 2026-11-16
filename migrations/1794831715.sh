#!/usr/bin/env bash

# The old kubectx conf.d snippet set KUBECONFIG for every fish shell from ~/.kube/clusters
# and wrote a merged ~/.kube/config on each start. Clusters now have a kubeconfig each, handed
# over by ocl, so it only exported an empty KUBECONFIG and emptied ~/.kube/config every time a
# terminal opened. Removed only when it is still the file we shipped.
SNIPPET="${XDG_CONFIG_HOME:-$HOME/.config}/fish/conf.d/kubectx.fish"
[[ -f $SNIPPET ]] || exit 0
grep -q 'Auto-merge all kubeconfigs in ~/.kube/clusters' "$SNIPPET" || exit 0
rm -f "$SNIPPET"
echo "  fish no longer rewrites ~/.kube/config on every start"
