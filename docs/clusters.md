# Clusters

OpenShift, RKE2, Talos and any other Kubernetes cluster, reached the same way:
`desktop-cluster`, or `ocl` for short.

    ocl                     pick a cluster, then a shell on it
    ocl NAME                a shell on NAME, signing in first when it is needed
    ocl -k NAME             k9s            ocl -a NAME     Argo CD (argo9s)
    ocl -c NAME             web console    ocl -t NAME     Talos dashboard
    ocl -x NAME CMD...      one command    ocl -e NAME     exports for this shell
    ocl status              every cluster asked at once: signed in, nodes, version
    ocl login NAME | logout NAME | list | names | edit

The same is in the menu (`Go → Clusters`), on the dashboard's Infrastructure tab, and in
voice commands: "k9s on lab", "argo on ocp302", "talos dashboard on edge".

## One kubeconfig per cluster

Each cluster has a kubeconfig of its own in `~/.local/state/desktop/clusters/NAME.kubeconfig`
(mode 600), and everything opened on a cluster is handed that file in `KUBECONFIG` and
nothing else. Nothing is kept in `~/.kube/config`. That is the point of it: with one shared
file, `kubectx` in one terminal moves every other terminal to the same cluster, and the
`kubectl delete` typed in the second one lands somewhere it was not meant to. Here a window
is on one cluster for as long as it is open, and signing out of a cluster is deleting its
file. Its context is named after the cluster, which is what the starship prompt shows.

A sign-in is written beside the old file and moved over it only when it worked, so a
cancelled password prompt leaves the previous kubeconfig as it was.

## clusters.conf

`~/.config/desktop/clusters.conf`, a line each: name, kind, then `key=value` settings.
`ocl edit` opens it, and starts it with an example when it is not there. It is never in the
repository: it names hosts, and the repository is public.

    # name    kind       how to reach it, and anything else
    ocp202    openshift  server=https://api.ocp202.example:6443 login=web
    lab       rke2       ssh=admin@lab-cp1.example namespace=apps
    edge      talos      talosconfig=~/.talos/edge.yaml nodes=192.0.2.11
    kind      kubernetes kubeconfig=~/.kube/clusters/kind.yaml

| Kind | Signing in | Needs |
|---|---|---|
| `openshift` | `oc login` to `server=`. `login=password` (default) asks for user and password, `login=web` uses the browser, `login=token` asks for a token. | `server=` |
| `rke2` | The kubeconfig RKE2 writes at `/etc/rancher/rke2/rke2.yaml`, fetched with `ssh=` (sudo on the node), or copied from `kubeconfig=`. Its `127.0.0.1` becomes the node's name, or `server=`. | `ssh=` or `kubeconfig=` |
| `talos` | `talosctl kubeconfig` with `talosconfig=` and `nodes=`. `ocl -t` opens `talosctl dashboard` with the same, and `TALOSCONFIG` is set in the shell. | `talosconfig=` |
| `kubernetes` | A kubeconfig you already have, copied from `kubeconfig=`. | `kubeconfig=` |

Any kind also takes `namespace=` (to start in), `console=` (for `-c`; OpenShift finds its
own), `argocd=` (Argo CD's namespace: `openshift-gitops` on OpenShift, `argocd` elsewhere),
`insecure=true` and `ca=`.

A client certificate (RKE2, Talos) runs out eventually; the cluster then answers
"Unauthorized", the state becomes `signed-out`, and opening it fetches a new kubeconfig.
A cluster that does not answer at all is `unreachable`, not signed out: it is not asked to
sign in again for a network that is down.

## Where it lives

| What | Where |
|---|---|
| The command | `bin/desktop-cluster`; `ocl` is a fish function calling it, `config/fish/functions/ocl.fish` |
| Dashboard | `desktop-dash infra` → `desktop-cluster status --json`; drawn by `shell/Dashboard/InfraPage.qml` |
| Menu | `show_clusters_menu` in `bin/desktop-menu` |
| Voice | `cluster_said` in `bin/desktop-voice`: any name in clusters.conf, as a word of its own |
| Completions | `config/fish/completions/desktop-cluster.fish`, `ocl.fish` |
| Clients | `oc` and `kubectl` (pinned, `desktop-update-oc`, `desktop-update-kubectl`); `talosctl` and kubie (`desktop-update-releases`); k9s; argo9s |

`ocl` used to be a script of its own with the list of clusters written into it
(`OCL_NAMES`) and every login in `~/.kube/config`. Migration `1794593713` carried both
over: each cluster's server into clusters.conf and its context into its own kubeconfig.
The old script is left where it was; the fish function is found before it.

## Checking it

    ./test/cluster-test.sh      every kind signed in to, with stubs; status; the migration
    ocl status                  the real clusters
