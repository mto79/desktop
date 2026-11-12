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
| `e` | The sidebar: a row per session, with its agents' state (see below) |
| `N` | Go to the agent needing you most; press again for the next |
| `g` | Every agent on this machine in a list, needing you first |
| `s`, `S` | Pick a session, pick a tab |
| `D` | Finish the task this window is on |
| `?` | Every key this desktop adds (`desktop-tmux-keys`) |

## The sidebar

The sidebar is on from the moment the tmux server starts: `tmux.conf` runs
`desktop-tmux-sidebar --on`, which a reload of the file leaves alone. `prefix + e` takes
the column away from every window, and puts it back. It is on or off for the whole tmux server, not for one window:
a pane lives in one window, so a single column would vanish the moment you used it to go
somewhere else.

     SPACES                    20
     ● checkmk                       its dot: the agent in it most in need of you
       main
    ▌● desktop              2 5m     the session you are in, on a bar: two blocked, 5m
    ▌  feat/sidebar +42 −7           its branch, and what the branch changed
     ● ocp-helm-charts        7m     stuck (peach): working, but silent for 7 minutes
       main
     · home                          no agents at all

     AGENTS               desktop    the agents of one session:
     ● claude 1 desktop-5f    5m     model and tab, its name for messages, how long
       blocked · fix-runner          its state in herdr's word, and its task
     ○ opencode 1
       idle                          idle, or an agent that reports nothing

     ⏎ go  p peek  v more  q hide

It is drawn as herdr's sidebar is, as near as a terminal pane allows: two sections, each
entry on two lines, a coloured dot for the state, the active row on a bar, Catppuccin
Mocha's colours (the nearest of the 256) and the keys along the bottom. A window that
missed its column -- the restore builds windows at login, before any client can give them
room -- gets one the first time it is looked at, behind a `@sidebar_held` mark so looking
at one that has its column costs nothing. The restore leaves the column out of what it
saves; the sidebar puts it back.

It is in two parts, as herdr's sidebar is. **On top, a row per session.** Windows are not
listed; a session's windows are on its own tab bar. When the sessions on two lines each
would take more than half the column, every session but the one you are in keeps to one,
so the agents underneath still fit: with twenty-odd sessions the list had filled a laptop's
column and left one agent in sight. The branch of any of them is a `v` away. The sessions an agent column or a
terminal pane's tabs are made of (`ai-desktop-12-claude`, `term-…`) are not listed either:
their agents belong to the session whose window holds that column.

**Underneath, the agents of one session**, each on a row of its own: the session under the
cursor, or the one you are in. Move the cursor over the sessions and the agents follow;
move on down into them and they stay. Every tab of an agent column is listed, in tab order,
by its model and number as on the column's own tab bar, and by its task when it works in
a worktree. A Claude Code session has its name after that -- `claude 1 vm-6a` -- the one
another agent sends it a message by, so "ask vm-6a what it changed" can be read off the
column. A name too long for the row loses its middle, not its end: four agents in one
repository are `opentofu-monorepo-b1`, `-14`, `-d8` and `-a1`. The name comes from Claude
Code's record of each running session, in `~/.claude/sessions/`, and counts only while that
session's process is alive and is the one that started then. An agent in a plain pane is named after its window. When a session has agents
in more than one window, each says which: `2:claude 1`. opencode and codex send no hooks,
so their tabs are always shown idle.

Each agent's name is drawn in its own colour, the one its tabs and pane border have:
`@agent-claude-colour`, `@agent-codex-colour` and `@agent-opencode-colour`, set by the theme
(`themes/<theme>/tmux.conf`). They are hex, and the sidebar draws the nearest of the
terminal's 256 colours; switching theme recolours an open sidebar at its next refresh. The
mark and the time keep the colour of the state.

A session's dot is the state of the agent in it that needs you most, with the number of
agents in that same state when there is more than one, and how long it has been so; its
second line is the branch of its directory and the lines it changed. An agent's dot is its
own, said in a word on its second line:

| Dot | Word | Means | Order |
|---|---|---|---|
| red `●` | blocked | waiting on you: a permission prompt or a question | first |
| red `✗` | crashed | | |
| peach `●` | stuck | working, but no sign of life for five minutes | |
| green `●` | done | finished, and you have not looked yet | |
| yellow `●` | working | | last |
| `○` | idle | at its prompt, or a finished turn already read | |
| `·` | | a session with no agent at all | |

A session whose dot is `○` or `·` is one you can leave alone.

| Key in the sidebar | Does |
|---|---|
| click, `Enter`, `l` | Go to the session; on an agent, straight to that agent |
| `j` `k`, arrows, wheel | Move; the agents shown follow the session under the cursor |
| `p` | Peek: the agent's screen in a popup, to answer it from there |
| `v` | More: each session's review and pipeline, and its other checkouts; under each agent its last prompt |
| `r` | Read everything again now |
| `q` | Close the sidebar, in every window |

The sidebar's keys are also on `prefix + ?`, under the prefix keys.

Going to an agent goes through `desktop-agent-tabs jump`, so an agent in a column's tabs
is reached by bringing its tab to the top of the column in the window holding it.

**Peek** (`p`, `desktop-agent-peek`) opens an agent in a popup -- on an agent's row that
agent, on a session's row the one marked there: its screen, read
again every second. In the popup:

| Key | Does |
|---|---|
| `1`–`9` | Typed into the agent: Claude Code's prompts take one key |
| `Enter`, `↑` `↓` | Passed on, for a menu |
| `i` | Type a line of reply, sent with Enter |
| `g` | Go to the agent and close the popup |
| `q`, `Esc` | Close, sending the agent nothing |

So a permission prompt in another session is answered without leaving the window you are
in. Esc closes rather than being passed on, because an Esc would cancel what the agent
asked; an agent that needs one is one to go to.

**The detailed view** (`v`) adds, under each agent, the prompt its turn began with, and
under each session a line for every checkout its agents work in, or the session's own
directory when it has none:

      desktop
        fix-runner  +42 −7  !12 ✗

The numbers are the lines the branch changed since it left the default branch, committed or
not. `!12` is the merge request (`#12` a pull request), followed by its pipeline (`✓`
passed, `✗` failed, `…` running) or by `merged` or `closed`. A checkout is named when that is
what tells it apart: a task's worktree, or more than one in a session. `v` switches every
window's column at once.

That line comes from `desktop-branch-status <dir>`, which prints it as JSON. Git it asks
every ten seconds at most. The forge (glab, or gh for GitHub) it asks in the background,
at most every three minutes, and keeps the answer under `$XDG_RUNTIME_DIR/desktop/
branch-status`, so a forge behind the VPN never holds the sidebar up. A forge that does not
answer leaves what it said before; only an answer can say a review is gone. Forgejo goes
without a review, since tea cannot ask for the review of a branch.

Only the columns on screen read tmux and the agents again, every two seconds; the others
ask nothing.

## Getting to the agent that needs you

`prefix + N` goes straight there, with no list in between: to the agent waiting longest,
then to a finished turn nobody has read (newest first), then to a stuck one. Pressed again,
it goes on to the next; the status line says which it is and how many there are
(`1/3  waiting 4m  checkmk`). When nothing needs you it says so and stays where it is. It
is `N` because `n` opens a new session.

`prefix + g` shows the same agents as a list to pick from, and the sidebar keeps them in
view.

## Agents talking to each other

Claude Code sessions on this machine can message each other by name, the name the sidebar
shows after the model and tab (`claude 1 vm-6a`). Ask one in plain words -- "ask vm-6a
which branch it is on" -- and the message arrives at the other between its turns, and the
answer comes back the same way. Nothing here is needed for that.

opencode and codex have no such thing, so `desktop-agent-send` types into their pane
instead, addressed as the sidebar shows them:

    desktop-agent-send vm "opencode 1" "the image builder's API changed, rebase"
    desktop-agent-send opentofu-monorepo claude-2 < notes.md
    desktop-agent-send --list

The text goes in as one bracketed paste, so a message of several lines is one message, and
then Enter. Sent from an agent's own pane, it is headed with who sent it and the command to
answer with, since the agent at the other end has no other way to know. The address is the
session and either the label (`opencode 1`, typed with or without its space) or a Claude
agent's name. It cannot tell whether opencode or codex is in the middle of a turn -- they
report nothing -- so a message to a busy one is handled however that agent handles typing.

## Saving and restoring

`desktop-tmux-restore` writes down what is open and rebuilds it at login, because a tmux
server does not survive a reboot.

`desktop-tmux-fresh` is the way out of that: it closes every session and deletes the
snapshot, so the next tmux starts empty and the next login restores nothing. It asks
first, unless given `-y`, and it works from inside tmux. Worktrees, tasks and the agents'
conversations are left alone.

tmux.conf loads no plugins. TPM used to run at the end of it, for tmux-resurrect and
tmux-yank, but neither was ever installed. `desktop-tmux-restore` does resurrect's job,
and `set-clipboard on` does yank's.

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

Every hook also touches the record, even when the state stays the same, so its mtime is the
last sign of life. A session "working" with no hook for five minutes
(`DESKTOP_AGENT_STUCK_AFTER`, in seconds) is stuck: a tool call that has not come back, a
turn interrupted with Esc, which fires no Stop, or a very long think. Its state stays
"working"; `desktop-agent-sessions` adds `"stuck": true`, and the sidebar marks it ⧗ with
how long it has been quiet.

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

Both are on the top bar of each AI column, behind `desktop-tmux-cached 30`. tmux runs a
`#()` once per client per `status-interval`, so with a dozen tabs attached the two Python
scripts started ten times a second and took two cores to print the same line. The wrapper
runs each at most once in thirty seconds and answers every other call from
`$XDG_RUNTIME_DIR/desktop-tmux-cached/`, with nothing but bash builtins.

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
| `desktop-agent-console` (`SUPER + ~`) | An agent in a window that drops over any workspace; the same key hides it, and it keeps running. tmux session `console`, in your home directory |
| `desktop-menu-agents` | List the running sessions and jump to one |
| `desktop-git-commit` | Commit what is staged with a message Claude writes from the diff; lazygit's `C` |

## What an agent may do

The Rights heading of the dashboard's AI tab (`desktop-dash rights`) has a card per agent, in
the sections [OpenShell](https://docs.nvidia.com/openshell/how-it-works/policies/schema.md)
governs: files, kernel sandbox, process, network, inference and keys. It keeps apart what an
agent promises, its own prompts, and what the kernel holds it to, read from `/proc` for each
running process. It only looks: places are tested with `access(2)`, the environment is reduced
to variable names, and it does not run `sudo`, whose refusals would land in the journal the
Security tab reads.

OpenShell is not needed for this and is not installed by `install/`. The page also lists what
OpenShell needs here. Codex differs from the others: its commands run in a sandbox of its own,
though Codex's own process has none.

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
