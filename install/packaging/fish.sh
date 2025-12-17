#!/usr/bin/env bash

# https://github.com/PatrickF1/fzf.fish

# List of conflicting files
conflicts=(
  "$HOME/.config/fish/functions/_fzf"*
  "$HOME/.config/fish/functions/fzf_configure_bindings.fish"
  "$HOME/.config/fish/conf.d/fzf.fish"
  "$HOME/.config/fish/completions/fzf_configure_bindings.fish"
)

echo "Removing conflicting fzf.fish files..."
for file in "${conflicts[@]}"; do
  rm -f $file
done

echo "Installing fzf.fish via Fisher..."
fish -c 'curl -sL https://raw.githubusercontent.com/jorgebucaran/fisher/main/functions/fisher.fish | source; fisher install PatrickF1/fzf.fish'

echo "fzf.fish installed (overwritten if needed)."
