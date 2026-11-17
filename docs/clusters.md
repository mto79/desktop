# Clusters

OpenShift, RKE2, Talos and any other Kubernetes cluster, reached the same way:
`desktop-cluster`, or `ocl` for short.

    ocl                     pick a cluster, then a shell on it
    ocl NAME                a shell on NAME, signing in first when it is needed
    ocl -k NAME             k9s            ocl -a NAME     Argo CD (argo9s)
    ocl -c NAME             web console    ocl -t NAME     Talos dashboard
    ocl -x NAME CMD...      one command    ocl -e NAME     exports for this shell
    ocl status              every cluster asked at once: signed in, nodes, version
    ocl session [NAME]      a tmux session on it: a shell and k9s
    ocl login NAME | logout NAME | list | names | edit

The same is in the menu (`Go → Clusters`), on the dashboard's Infrastructure tab, and in
voice commands: "k9s on lab", "argo on ocp302", "talos dashboard on edge".

In tmux, `prefix + K` is to clusters what `prefix + f` is to repositories: pick one, sign in
if it needs it, and go to a session named after it, with a `shell` window, a `k9s` window
and an `argo` window (argo9s, when it is installed) on its kubeconfig. Signing in comes
first, so the windows do not each open a browser; a session already there is gone to rather
than made again.

### The agent column

The `shell` window of a cluster's session has an agent column on its right, as a
repository's `ide` window has (`desktop-agent-layout --column`: the column alone, no
editor). The agent may read and write files but must not reach the cluster, so it works in a folder
of the cluster's own, `~/clusters/NAME` (`DESKTOP_CLUSTER_AGENT_HOME` moves it), fenced for
each of the three agents the column can hold. The fence is merged into whatever settings
the folder already has, every time the session is made. The network is the fence that
matters -- without it a kubeconfig is no use -- and keeping the kubeconfigs unread is what
keeps a token out of what goes to the model's provider.

| Agent | What keeps it off the cluster |
|---|---|
| claude | `.claude/settings.json`: Bash in Claude Code's sandbox (bubblewrap), `failIfUnavailable` and no unsandboxed retry; the sandbox cannot read `~/.local/state/desktop/clusters`, `~/.kube`, `~/.talos` or clusters.conf, and denies every `server=`, `console=` and `ssh=` host in clusters.conf. Deny rules for the cluster tools (oc, kubectl, kubecolor, ocl, desktop-cluster, k9s, argo9s, talosctl, kubie, kubens, kubectx, argocd) and for reading those files with its own Read tool, which the sandbox does not cover. `KUBECONFIG=/dev/null`, and bypass-permissions mode disabled. |
| codex | `.codex/config.toml`: `workspace-write` sandbox with no network at all, `KUBECONFIG=/dev/null`. codex reads a project's config only in a trusted folder, so the folder is added to `~/.codex/config.toml` as trusted, once. |
| opencode | `opencode.json`: `enabled_providers` is only what `opencode-providers=` in `~/.config/desktop/cluster-agents.conf` names -- the organisation's own models, kept out of this public repository -- and nothing when it names none. The same tools denied, and the same files. opencode has no sandbox: its own docs call these rules best effort. |

The column's agents also run in tmux sessions of their own, which never had the cluster's
`KUBECONFIG` in the first place.

A cluster's session is marked `@cluster`, and `desktop-tmux-restore` does not save it: made
again at login it would be a shell on no cluster. `prefix + K` makes it, signing in first.

## One kubeconfig per cluster

Each cluster has a kubeconfig of its own in `~/.local/state/desktop/clusters/NAME.kubeconfig`
(mode 600), and everything opened on a cluster is handed that file in `KUBECONFIG` and
nothing else. Nothing is kept in `~/.kube/config`. That is the point of it: with one shared
file, `kubectx` in one terminal moves every other terminal to the same cluster, and the
`kubectl delete` typed in the second one lands somewhere it was not meant to. Here a window
is on one cluster for as long as it is open, and signing out of a cluster is deleting its
file. Its context is named after the cluster, which is what the starship prompt shows.

The shell `ocl NAME` opens is kubie's when kubie is installed, as the old `ocl`'s was. kubie
works on a copy of the cluster's kubeconfig, so `kubie ns` (fzf over the namespaces when
given none) moves that shell alone; `kubens` would write the namespace into the cluster's
file, which every other window on it reads, k9s in `ocl session` included. kubie starts the
shell it finds as its parent, so it is run from `$SHELL -c` rather than exec'd: started from
the menu or the dashboard, its parent would be the terminal and it would fail.

At the prompt, `kubectl` and `oc` are fish functions that run them through kubecolor
(`config/fish/conf.d/kubecolor.fish`), which colours what they print. Only in an interactive
shell; desktop-cluster and every script call the command itself. kubecolor runs oc rather
than kubectl when `KUBECTL_COMMAND=oc`, which the `oc` function sets.

Signing in to a cluster, or opening its session, also opens its web GUIs -- console, Argo
CD, Grafana -- as one browser window ready on workspace 1, and `ocl logout` closes it: see
[guis.md](guis.md).

`ocl logout` also closes the cluster's tmux session. Everything in it held a copy of the
token the sign-out revokes, so it had all stopped working while still looking signed in.

In `ocl session` the shell window's shell is marked as its terminal, so `prefix + t` there
adds a terminal tab as it does under a repository's editor (`desktop-terminal-tabs`), and
each tab runs another `ocl NAME` -- a shell on the cluster, not a plain one.

`ocl login` and `ocl logout` delete the dashboard's cached cluster status, which it otherwise
keeps for two minutes, and age the tmux sidebar's (`$XDG_RUNTIME_DIR/desktop/clusters.json`,
one minute) so that it asks again; a sign-out is written into the sidebar's at once.

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

`env=` says which environment a cluster is -- `devl`, `test`, `acpt`, `prod`, or any word.
The sidebar shows it after the cluster's name, production in red, acceptance in peach, test
in yellow and development in green, and `ocl list` and `ocl status` show it as a column.

`dir=` is the folder a cluster's session and its agent column work in (`~` allowed), made
and fenced when the session is; without it, `~/clusters/NAME`. A session already open keeps
the folder it was made in until it is closed.

    ocp202    openshift  server=https://api.ocp202.example:6443 env=devl dir=~/Work/Clusters/ocp202

`login=web` gives the sign-in page a web-app window of its own rather than a tab in the
browser, and closes it once `oc login` returns, whether the sign-in worked or not. oc opens
the page with `xdg-open`; during the sign-in an `xdg-open` of desktop-cluster's own comes
first on `PATH`. Over ssh, with no Hyprland, oc opens the page the way it always has.

`oc login --web` waits for the browser's callback for as long as it takes, so it is watched:
the sign-in window seen and then closed gives the sign-in up, and so do five minutes without
one (`DESKTOP_CLUSTER_WEB_PATIENCE`, in seconds). Before that, a window closed unfinished left
oc waiting for good, and with it the tmux `cluster` window the sidebar had opened.

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
| Clients | `oc` and `kubectl` (pinned, `desktop-update-oc`, `desktop-update-kubectl`); `talosctl`, kubie and kubecolor (`desktop-update-releases`); k9s; argo9s |

`ocl` used to be a script of its own with the list of clusters written into it
(`OCL_NAMES`) and every login in `~/.kube/config`. Migration `1794593713` carried both
over: each cluster's server into clusters.conf and its context into its own kubeconfig.
The old script is left where it was; the fish function is found before it.

## Checking it

    ./test/cluster-test.sh      every kind signed in to, with stubs; status; the migration
    ocl status                  the real clusters
