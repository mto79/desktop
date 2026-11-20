#!/usr/bin/env bash

# Pick a repository, or a task in one, and go there.
#
# Repositories come from the directories listed in $TMUX_SESSIONIZER_CONFIG_FILE. A
# directory there that is itself a repository -- the desktop, llm-wiki -- is offered as
# that repository; any other is a folder of them, and each directory in it is offered.
# Listing a repository used to offer its bin/, config/ and .git/ instead. Tasks are the
# worktrees desktop-worktree keeps beside them -- gitops.worktrees/fix-runner -- listed
# under the repository they belong to. The *.worktrees directories themselves are not
# repositories and are not offered as one.
#
# Home comes first: the plain "home" session, a shell in ~ with no layout, which is
# where a day in tmux starts and the way back to it.
#
# Sessions are made by desktop-repo-session and task windows by desktop-worktree, the same
# code that makes them everywhere else, so a session looks the same however it was opened.

switch_to() {
  if [[ -z $TMUX ]]; then
    tmux attach-session -t "=$1"
  else
    tmux switch-client -t "=$1"
  fi
}

candidates() {
  local root
  echo "$HOME"
  while read -r root; do
    [[ -n $root && $root != \#* ]] || continue
    root=${root/#\~/$HOME}
    [[ -d $root ]] || continue
    if [[ -e $root/.git ]]; then
      echo "$root"
      find "$root.worktrees" -mindepth 1 -maxdepth 1 -type d 2>/dev/null
    else
      find "$root" -mindepth 1 -maxdepth 1 -type d ! -name '*.worktrees'
      find "$root" -mindepth 2 -maxdepth 2 -type d -path '*.worktrees/*'
    fi
  done <"$TMUX_SESSIONIZER_CONFIG_FILE" 2>/dev/null
}

if [[ $# -eq 1 ]]; then
  selected=$1
else
  # Home stays on top; the rest sorted, so a task sits under its repository.
  selected=$(
    candidates | { read -r first; echo "$first"; sort -u; } | fzf
  )
fi

[[ -n $selected ]] || exit 0
selected=${selected%/}

if [[ $selected == "$HOME" ]]; then
  tmux has-session -t "=home" 2>/dev/null || tmux new-session -d -s home -c "$HOME"
  switch_to home
  exit 0
fi

if [[ $selected == *.worktrees/* ]]; then
  exec desktop-worktree open "$selected"
fi

name=$(desktop-repo-session "$selected") || exit 1
switch_to "$name"
