#!/usr/bin/env bash

# Pick a repository, or a task in one, and go there.
#
# Repositories come from the directories listed in $TMUX_SESSIONIZER_CONFIG_FILE. Tasks are
# the worktrees desktop-worktree keeps beside them -- gitops.worktrees/fix-runner -- listed
# under the repository they belong to. The *.worktrees directories themselves are not
# repositories and are not offered as one.
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

if [[ $# -eq 1 ]]; then
  selected=$1
else
  roots=$(eval echo $(xargs <"$TMUX_SESSIONIZER_CONFIG_FILE"))
  selected=$(
    {
      find $roots -mindepth 1 -maxdepth 1 -type d ! -name '*.worktrees'
      find $roots -mindepth 2 -maxdepth 2 -type d -path '*.worktrees/*'
    } 2>/dev/null | sort | fzf
  )
fi

[[ -n $selected ]] || exit 0

if [[ $selected == *.worktrees/* ]]; then
  exec desktop-worktree open "$selected"
fi

name=$(desktop-repo-session "$selected") || exit 1
switch_to "$name"
