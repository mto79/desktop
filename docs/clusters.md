# Clusters

OpenShift, RKE2, Talos and any other Kubernetes cluster, reached the same way:
`desktop-cluster`, or `ocl` for short.

    ocl                     pick a cluster, then a shell on it
    ocl NAME                a shell on NAME, signing in first when it is needed
    ocl --here NAME         the same, in this terminal rather than NAME's tmux session
    ocl -k NAME             k9s            ocl -a NAME     Argo CD (argo9s)
    ocl -c NAME             web console    ocl -t NAME     Talos dashboard
    ocl -x NAME CMD...      one command    ocl -e NAME     exports for this shell
    ocl status              every cluster asked at once: signed in, nodes, version
    ocl login NAME | logout NAME | list | names | edit

`ocl` with no name, or `prefix + K` in tmux, opens the list of clusters in a popup, the
same shape as the agents' on `prefix + g`:

     cluster>
     healthy      ocp202               openshift   https://api.ocp202.example:6443
     degraded     ocp204               openshift   https://api.ocp204.example:6443  production
     ?            lab                  rke2        admin@lab-cp1.example
       Enter goes there · ^k k9s · ^a Argo CD · ^t Talos · ^o console · Esc closes

Enter goes to the cluster's session; `ocl -k` with no name makes Enter open k9s instead.
The state is the dashboard's last look (`?` when it has none): the list opens at once rather
than wait seconds for every cluster to answer. Outside tmux it is the same list in the
terminal, and with no terminal at all -- started from a key -- the desktop's own menu.

Clusters are also in the session picker on `prefix + s`, with repositories and views
([views.md](views.md)); a view can name a cluster, and is then on it as a whole.

The same is in the menu (`Go → Clusters`), on the dashboard's Infrastructure tab, and in
voice commands: "k9s on lab", "argo on ocp302", "talos dashboard on edge".

## A tmux session per cluster

A cluster is a place, as a repository is. `ocl NAME` goes to its tmux session, `k8s-NAME`,
making it the first time: a `shell` window, and `k9s`, `argo` and `talos` windows as
`-k`, `-a` and `-t` ask for them -- each opened once and gone back to after, found by a
`@cluster_action` mark rather than by its name, which the shell in it is free to change.
Inside tmux this client switches there; outside, the terminal attaches to it, so the menu
and voice commands land in the same session.

The cluster is in the session's environment (`KUBECONFIG`, `DESKTOP_CLUSTER`,
`DESKTOP_CLUSTER_KIND`, and `TALOSCONFIG` for Talos), so every window opened in it later
is on that cluster too. An agent column or a terminal's tabs opened there are tmux
sessions of their own, which tmux would start from the global environment instead;
`desktop-agent-tabs` and `desktop-terminal-tabs` copy the cluster over (`cluster_env`).
The session carries `@cluster NAME`, which is how the sidebar knows it.

After a reboot `desktop-tmux-restore` builds a cluster's session again through
`desktop-cluster --detached`, so it comes back with its cluster, not as a session that only
has the name. It remembers which sessions are clusters' by their `@cluster` mark.

`ocl --here NAME` is the old way: a shell in the terminal you are in. Without tmux
installed, that is what every `ocl` does.

## In the tmux sidebar

A cluster's session is listed with the repositories, with the cluster as its second line
where a repository has its branch: `⎈ ocp204`. And an agent that can reach a cluster says
which, after its state: `blocked ⎈ ocp204 · fix-runner`. That is read from the agent's own
process -- `DESKTOP_CLUSTER`, or a `KUBECONFIG` in ocl's store -- so it is the cluster a
`kubectl` it runs would reach, not a guess; an agent whose record names no process is found
under its pane. A process's environment cannot change, so each is read once.

`prod=true` in clusters.conf draws the cluster in red, in the sidebar and in the shell's
first line. An agent with production in reach should be seen to have it.

## Agents ask before they touch a cluster

Every time, a read included. `desktop-agent-hooks` gives Claude Code a `PreToolUse` hook,
`desktop-agent-cluster-guard`, which answers "ask" for any tool call that would reach a
cluster, and the agent stops at a permission prompt naming which:

    This runs kubectl: it reaches a Kubernetes cluster (PRODUCTION cluster ocp204).
    Allow it this once?

What counts: kubectl, oc, helm, k9s, talosctl, argocd, flux, kubie, ocl and the like in
command position -- first, after `;` `&&` `|` `$(`, or behind `sudo`, `env` or
`watch -n 2` -- and any tool opening a kubeconfig or talosconfig, or a Bash call naming
one. A command that only mentions one (`grep oc`, `echo kubectl`) is let through, and so
is anything the guard cannot read: it must never be what breaks an agent. It takes about
fifteen milliseconds a call.

Each agent is told in its own words, from the one list (`desktop-agent-cluster-guard --tools`),
all written by `desktop-agent-hooks`:

| Agent | How it asks | Where |
|---|---|---|
| Claude Code | the guard, as a `PreToolUse` hook answering "ask" | `~/.claude/settings.json` |
| codex | its own rules, `prefix_rule(pattern=["kubectl"], decision="prompt")`: codex shows "Would you like to run the following command?" with the reason "reaches a Kubernetes cluster" | `~/.codex/rules/desktop-clusters.rules` |
| opencode | its own permissions, `"kubectl *": "ask"` and the rest | `~/.config/opencode/opencode.json` |

Why not the guard for all three: codex (0.169) lists "ask" in its hook schema but calls it
unsupported when a hook answers it -- and then runs the command. Its rules ask properly. Under
codex's `on-request` approval policy you are asked; under a stricter one codex refuses the
command outright. Either way it does not run unasked.

opencode checks its rules against every command of a line, after `&&` and `|` too, and takes
the **last** rule that matches. So the cluster rules are kept after any rules of your own,
including a catch-all `"*": "allow"`, which would otherwise undo them. A value of your own
for one of the same patterns (`"helm *": "allow"`) is kept: that is your decision.

Neither codex nor opencode looks inside a file the way the guard does: reading a kubeconfig
with their own file tools is not asked about.

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

Any kind also takes `prod=true` (drawn in red; see above), `namespace=` (to start in), `console=` (for `-c`; OpenShift finds its
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
| Sessions | `to_session` in `bin/desktop-cluster`; `cluster_env` in `desktop-agent-tabs` and `desktop-terminal-tabs` |
| Sidebar | `cluster_in`, `cluster_under`, `production` in `bin/desktop-tmux-sidebar` |
| Picker | `cmd_pick` and `fzf_pick` in `bin/desktop-cluster`; `prefix + K` in `config/tmux/tmux.conf` |
| Permission | `bin/desktop-agent-cluster-guard`, wired by `bin/desktop-agent-hooks` |
| Voice | `cluster_said` in `bin/desktop-voice`: any name in clusters.conf, as a word of its own |
| Completions | `config/fish/completions/desktop-cluster.fish`, `ocl.fish` |
| Clients | `oc` and `kubectl` (pinned, `desktop-update-oc`, `desktop-update-kubectl`); `talosctl` and kubie (`desktop-update-releases`); k9s; argo9s |

`ocl` used to be a script of its own with the list of clusters written into it
(`OCL_NAMES`) and every login in `~/.kube/config`. Migration `1794593713` carried both
over: each cluster's server into clusters.conf and its context into its own kubeconfig.
The old script is left where it was; the fish function is found before it.

## Checking it

    ./test/cluster-test.sh      every kind signed in to, with stubs; sessions; status; the migration
    ./test/tmux-sidebar-test.sh a cluster's session and each agent's cluster, from a /proc of its own
    ./test/agent-cluster-guard-test.sh  what asks and what does not
    ocl status                  the real clusters
