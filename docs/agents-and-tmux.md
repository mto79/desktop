# Agents and tmux

Coding agents (Claude Code, OpenCode, Codex) run in tmux, in windows nobody is looking at
most of the time. Nearly everything here exists to answer one question without going to
look: which of them needs me?

## Sessions and windows

A repository gets one tmux session, named after its directory, made by
`desktop-repo-session`: an `ide` window laid out for an agent and a `git` window running
lazygit. The sessionizer and `desktop-worktree` both go through it, so they agree on the
name and the shape.

`desktop-agent-layout <target> <agent>...` lays a window out:

    +--------------------+--------+
    |                    |        |
    |      $EDITOR       | agent  |
    |                    |        |
    +--------------------+        |
    | shell  1 2         | 1  2   |
    +--------------------+--------+

The agent column holds tabs, one per agent, run by `desktop-agent-tabs`. The shell pane
holds tabs too, through `desktop-terminal-tabs`.

| Key (after the tmux prefix, `Ctrl-a`) | Does |
|---|---|
| `t`, `Tab`, `x` | New terminal tab, next tab, close the tab on top |
| `e` | The sidebar: every session, its windows and their agents |
| `s`, `S` | Pick a session, pick a tab |
| `D` | Finish the task this window is on |
| `?` | Every key this desktop adds (`desktop-tmux-keys`) |

`desktop-tmux-restore` writes down what is open and rebuilds it at login, because a tmux
server does not survive a reboot.

## What an agent is doing

`desktop-agent-hooks` merges hooks into Claude Code's `settings.json`. Each hook event
calls `desktop-agent-state`, which keeps one JSON file per session under
`$XDG_RUNTIME_DIR/desktop/agents`:

| Hook event | State |
|---|---|
| `SessionStart` | ready |
| `UserPromptSubmit`, `PostToolUse` | working |
| `Notification` | waiting (a permission prompt or a question), or done (the idle reminder) |
| `Stop` | done |
| `SessionEnd` | the record is removed |

The record holds the tmux pane and its server's socket, so a panel can jump straight to
the session, and the agent's pid, so a crashed session can be told from a quiet one: a
crash fires no `SessionEnd`.

The same state is shown in the tmux tab of the window, in the sidebar, on the bar
(`desktop-status-ai`), in the AI panel (`desktop-agent-sessions`), as a notification when
you are needed, and out loud through `desktop-say`.

opencode's providers come from two files: `~/.config/opencode/opencode.json`, deployed
from the repository, and `~/.config/opencode/local.json`, which is this machine's own and
is where an employer's model service goes.

`desktop-agent <agent>` is the wrapper the panes run. A clean exit says nothing; a crash
sends a notification naming the project.

opencode is the exception to that. Its renderer dies of SIGILL when the display scale
under it changes, as when a window moves between the laptop screen (scale 2) and a
monitor at scale 1, and logging in docked does that to every agent pane at once
([anomalyco/opencode#42094](https://github.com/anomalyco/opencode/issues/42094)). The
wrapper starts it again with `--continue`, so the pane goes back into its conversation.
It passes no `--continue` when another opencode runs in the same directory, whose session
could be the last one there, and none when the pane was started on a `--session` of its
own. A crash in the first five seconds, or a fourth one within ten minutes, is not
restarted and gets the notification.

`desktop-agent-tokens` counts tokens per local day per agent from what each one leaves on
disk. `desktop-status-claude` reports Claude Code's usage limits.

## Tasks in worktrees

Two agents on two changes in one checkout trample each other's files. `desktop-worktree`
gives each task its own git worktree, branch and tmux window:

    desktop-worktree new <branch>      # from inside a repository
    desktop-worktree list
    desktop-worktree done              # from inside a task: push, open the review, close
    desktop-worktree prune             # forget tasks whose review was merged

The worktree goes **next to** the repository (`gitops.worktrees/fix-runner/`), not inside
it, where every tool that walks the tree would find it.

"Done" is a review, not a merge: the branch is pushed and a merge request (`glab`) or pull
request (`gh`) is opened, then the window and worktree go. The branch stays until the
forge says the review was merged.

Files git does not track are missing from a fresh worktree. List them per repository in
`~/.config/desktop/worktrees/<repository name>`, or in a `.worktree` file in the
repository:

    symlink .vault_password
    copy    .env
    run     ansible-galaxy install -r requirements.yml

Symlink by default, because a copied secret is one more copy of the secret.

The git stash is shared between a repository and all its worktrees. Do not use a bare
`git stash pop` in one while another session may be using it.

## From outside tmux

| Command | Does |
|---|---|
| `desktop-agent-prompt` (`SUPER + A`) | Ask for an agent and a prompt, then run it |
| `desktop-menu-agents` | List the running sessions and jump to one |
| `desktop-git-commit` | Commit what is staged with a message Claude writes from the diff; lazygit's `C` |

## Review requests

`desktop-reviews` pops up a notification when a merge request or pull request starts
waiting for you: open, someone else's, with you as a reviewer or the assignee. The popup
is headed by the forge (GitLab, GitHub, Forgejo, or Codeberg for codeberg.org), says who
asks and the subject, with the project and number under it, and a click opens the
request in the browser. It is also said aloud through `desktop-say` -- "On GitLab, Bob
asks for your review: fix the login" -- with a commit-style prefix such as `feat(helm):`
left out of what is read. `speak = no` in `~/.config/desktop/reviews.conf` keeps the
popups and drops the voice; `desktop-say --mute` silences everything.

`desktop-reviews.timer` runs it every five minutes. `desktop-reviews --list` prints, host
by host, what is waiting or why a host said nothing (not reachable, did not answer), and
notifies nobody. `desktop-reviews --example` pops up and says one made-up request from
each forge you are logged in to, exactly as a real one would look; a click on one opens
that host's real list.

It asks every host glab, gh and tea are logged in to, read from their own configuration
at each run: GitLab through glab, GitHub through gh, Forgejo and Gitea -- Codeberg among
them -- through tea. A new instance needs only a `glab auth login` or a `tea login add`,
and no host is named in this repository. tea is installed by `install/packaging/tea.sh`,
one pinned version checked against a checksum written there. A host that does not
answer, because it is only reachable over the VPN, is skipped without a message, and
what it already showed is kept; only a host that answered can say a request is gone. The
first check of a host gives one popup with the number already waiting and a link to the
list, and more than five new requests at once are one popup as well. What has been shown
is kept per host under `~/.local/state/desktop/reviews/`.
