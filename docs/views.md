# Views and the session picker

A tmux session here is one of three kinds of place:

| Kind | What it is | Made by | Session name | In the sidebar |
|---|---|---|---|---|
| Repository | a checkout: editor, agent column, lazygit | `desktop-repo-session` | the directory's name | its branch |
| Cluster | a Kubernetes cluster: a shell on it, k9s, Argo CD | `ocl` ([clusters.md](clusters.md)) | `k8s-NAME` | `⎈ NAME` |
| View | anything you lay out once and want again | `desktop-view` | `view-NAME` | `◆ view` |

`prefix + s` lists all of them in one popup, open or not.

## The session picker: `prefix + s`

     session>
     ▌  desktop            repo      open   ~/Repositories/desktop
        gitops             repo      open   ~/Repositories/gitops
     ⎈  k8s-ocp204         cluster   open   ocp204
     ◆  view-gitlab        view      open   GitLab upgrade on ocp204
     ◆  release            view             The monthly release, three repositories
     ⎈  lab                cluster          rke2
        terraform          repo             ~/Repositories/terraform
        terraform · fix-x  task             ~/Repositories/terraform.worktrees/fix-x
       Enter goes there · ^e edit the view · ^n save this session as a view · Esc closes

What is open comes first, with the session you are in on a bar (`▌`). After that come the views,
clusters, repositories and tasks that are not open. One list both switches and opens:

| Key | Does |
|---|---|
| Enter | Go there. Something not open is opened by its own command first: `desktop-view open`, `desktop-cluster`, `desktop-repo-session`, `desktop-worktree open`. A session opened from here is the same as one opened any other way. |
| `^e` | Edit the view under the cursor, open or not, in `$EDITOR`. |
| `^n` | Save the session you opened the popup from as a view. It asks for a name. |
| Esc | Close. |

It looks and behaves like the agents' list (`prefix + g`) and the clusters' list (`prefix + K`):
the same reversed fzf, colours, and keys in the header. It also moves the client that opened it,
named explicitly, because a popup is not a pane of any client.

- **Repositories** come from the sessionizer's roots, the directories listed in
  `$TMUX_SESSIONIZER_CONFIG_FILE`. `prefix + f` is still the sessionizer on its own.
- **Not listed:** the sessions behind an agent column or a terminal's tabs (`ai-…`, `term-…`).
  They belong to the session whose window holds them, as in the sidebar.
- **Without a popup:** `desktop-pick --list` prints the rows with no fzf.

`prefix + s` used to be a tmux menu of open sessions only. That menu is still there as
`desktop-agent-tabs pick CLIENT sessions`, but nothing is bound to it.

## Views

A view is a session you lay out once, keep in a file, and open again by name. An upgrade of
GitLab is neither a repository nor a cluster. It needs the charts' repository, an agent
reading the release notes, k9s on the cluster it runs on, and a pane tailing its logs.
A view holds all of that and builds it the same way every time.

    desktop-view open NAME [--detached]   # build it, or go to it if it is open
    desktop-view save NAME [--force]      # the session you are in, written down as NAME
    desktop-view edit NAME                # the file in $EDITOR; a new one starts from an example
    desktop-view show NAME                # what open would build, without building it
    desktop-view list                     # every view: open or not, its cluster, what it is for
    desktop-view rm NAME                  # delete the file (an open session is left alone)

### Making one

Either lay the session out by hand and save it:

1. Open windows, split panes, start an agent, run `ocl` for a cluster window.
2. `prefix + s`, then `^n`, and give it a name (or `desktop-view save NAME` from inside it).
3. `desktop-view edit NAME` to tidy what was written: add a description, a prompt, a cluster.

Or write it from nothing: `desktop-view edit NAME` starts from an example.

### The file

`~/.config/desktop/views/NAME.toml`. TOML, because Python reads it without a library, it is
pleasant to write by hand, and it says what each window *is* rather than how big its panes are.

```toml
description = "GitLab upgrade on ocp204"   # shown in the picker and in `list`
dir = "~/Repositories/gitlab-helm"         # where every window starts unless it says otherwise
cluster = "ocp204"                         # optional: the whole session is on this cluster

[[window]]
name = "ide"
kind = "agent"                 # editor, terminal and an agent column, as desktop-agent-layout makes them
model = "claude"               # the model the column shows; claude when left out
tabs = 2                       # tabs of that model; or a table: { claude = 2, opencode = 1 }
prompt = "Read UPGRADE.md and plan the move to 18.x"   # typed into the first tab, not sent

[[window]]
name = "k9s"
kind = "k9s"                   # or "argo", "talos": on the view's cluster, as `ocl -k` opens it

[[window]]
name = "notes"
dir = "~/Notes/gitlab"         # relative to the view's dir, or absolute, or ~
panes = [""]                   # one shell

[[window]]
name = "watch"                 # kind = "shell" is the default
layout = "even-horizontal"     # any tmux layout name, or a layout string as tmux prints them
panes = [
  "watch kubectl -n gitlab get pods",
  { dir = "~/Repositories/gitlab-helm/charts", command = "kubectl -n gitlab logs -f deploy/webservice" },
]
```

| Key | Where | Means |
|---|---|---|
| `description` | top | What the view is for. Shown in the picker. |
| `dir` | top | Where windows start. Default `~`. |
| `cluster` | top | A name from `clusters.conf`. The session's environment carries it, so every window, every pane and every agent in the view is on that cluster. |
| `name` | window | The window's name. Must be unique in the view. Defaults to its kind. |
| `kind` | window | `agent`, `shell` (default), `k9s`, `argo`, `talos`. The last three need `cluster`. |
| `dir` | window | Where this window starts, if not the view's `dir`. |
| `model`, `tabs`, `terminals` | agent | The agent column: which model is on show, how many tabs of each, how many terminal tabs. |
| `prompt` | agent | Typed into the first tab once the agent is up, and left there for you to read and send. |
| `panes`, `layout` | shell | Each pane is a command, or `{ dir, command }`. `""` is a plain shell. |

### What open does

1. If `view-NAME` is open, it goes there and stops, so opening a view twice never builds it twice.
2. It makes `view-NAME` and marks it `@view NAME`, plus `@cluster` and the cluster's environment
   if it has one.
3. It builds each window in the file's order:
   - **Agent windows** use the same code `desktop-tmux-restore` uses after a reboot, so an
     agent window in a view is an ordinary one.
   - **k9s, Argo CD and Talos** run `desktop-cluster --here`.
   - **Shell panes** start a shell, and the command is typed into it and run. When the command
     ends, or you stop it, the pane is still a shell in the same place.
4. It types an agent's `prompt` once the agent has started, in the background, without
   pressing Enter. A view opened out of habit should not start work by itself.
5. It moves you there: the client that asked, or the terminal you ran it in. `--detached`
   builds it and stays put.

A file written wrong is refused before anything is built, and every mistake in it is listed:
a `dir` that does not exist, an unknown `kind`, k9s with no `cluster`, two windows with one
name, a TOML error with its line.

### What save writes

`desktop-view save` describes the session you are in, in the file's terms:

- an agent window as `kind = "agent"` with its model and tabs, and a commented `prompt` to fill in
- a cluster window made by `ocl` as `k9s`, `argo` or `talos`, not as the shell it runs in
- every other pane by the command running in it now, read from the process, so a shell where
  you typed `watch kubectl get pods` is saved as that command. A shell running nothing is `""`.
  Only the command that is running is saved: `echo one; sleep 200` running `sleep` is saved as
  `sleep 200`.
- the session's directory as `dir`, and its cluster if it is on one

The window layout is saved as tmux prints it, which is tied to the window's size. Replacing
it with a name (`even-horizontal`, `main-vertical`, `tiled`) usually reads better.

It will not write over a view that exists; `--force` does.

### Agents and clusters in a view

A view with `cluster = "ocp204"` puts `KUBECONFIG`, `DESKTOP_CLUSTER` and
`DESKTOP_CLUSTER_KIND` in its session's environment. Everything opened in it inherits them,
including an agent column, whose tabs are tmux sessions of their own: `desktop-agent-tabs`
copies the cluster across when it makes them (`cluster_env`). So:

- the sidebar says `⎈ ocp204` under every agent in the view, red if it is `prod=true`
- an agent still asks before it touches the cluster: the guard in [clusters.md](clusters.md)
  does not care how the agent was started

### After a reboot

`desktop-tmux-restore` writes a view's session down as the view's name. It rebuilds it with
`desktop-view open --detached` from the file as it is then, so a view edited since comes
back edited. A window you added to the session by hand after opening it is put back as well,
as any window is, and is on the view's cluster with the rest.

## Where it lives

| What | Where |
|---|---|
| Views | `bin/desktop-view`; the files in `~/.config/desktop/views/` |
| The picker | `bin/desktop-pick`; `prefix + s` in `config/tmux/tmux.conf` |
| Building windows | `build_agent` in `bin/desktop-tmux-restore`, shared with the restore |
| The sidebar's `◆ view` | `collect` and `layout` in `bin/desktop-tmux-sidebar` |
| After a reboot | `snapshot` and `restore` in `bin/desktop-tmux-restore` |
| Completions | `config/fish/completions/desktop-view.fish` |

## Checking it

    ./test/view-test.sh         a view built, saved, refused, listed, picked and restored, on a tmux of its own
    desktop-view show NAME      what a view would build
    desktop-pick --list         what the picker would show
