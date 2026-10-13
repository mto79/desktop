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
