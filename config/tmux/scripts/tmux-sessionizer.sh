#!/usr/bin/env bash

switch_to() {
  if [[ -z $TMUX ]]; then
    tmux attach-session -t $1
  else
    tmux switch-client -t $1
  fi
}

has_session() {
  tmux list-sessions | grep -q "^$1:"
}

hydrate() {
  if [ -f $2/.tmux-sessionizer ]; then
    tmux send-keys -t $1 "source $2/.tmux-sessionizer" c-M
  elif [ -f $HOME/.tmux-sessionizer ]; then
    tmux send-keys -t $1 "source $HOME/.tmux-sessionizer" c-M
  fi
}

if [[ $# -eq 1 ]]; then
  selected=$1
else
  selected=$(find $(eval echo $(xargs <$TMUX_SESSIONIZER_CONFIG_FILE)) -mindepth 1 -maxdepth 1 -type d | fzf)
fi

if [[ -z $selected ]]; then
  exit 0
fi

selected_name=$(basename "$selected" | tr . _)
tmux_running=$(pgrep tmux)

if [[ -z $TMUX ]] && [[ -z $tmux_running ]]; then
  # Create session with first window named "editor" running nvim +Neotree
  tmux new-session -s "$selected_name" -n editor -c "$selected" 'nvim +Neotree'
  hydrate $selected_name $selected
  # Add lazygit window
  tmux new-window -t "$selected_name:" -n lazygit -c "$selected" 'lazygit'
  # Re-select the "editor" window
  tmux select-window -t "$selected_name:editor"
  exit 0
fi

if ! has_session $selected_name; then
  # Create session with first window named "editor" running nvim +Neotree
  tmux new-session -ds "$selected_name" -n editor -c "$selected" 'nvim +Neotree'
  hydrate $selected_name $selected
  # Add lazygit window
  tmux new-window -t "$selected_name:" -n lazygit -c "$selected" 'lazygit'
  # Re-select the "editor" window
  tmux select-window -t "$selected_name:editor"
fi

switch_to $selected_name
