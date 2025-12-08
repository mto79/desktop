#!/usr/bin/env bash

DESKTOP_MIGRATIONS_STATE_PATH=~/.local/state/desktop/migrations
mkdir -p $DESKTOP_MIGRATIONS_STATE_PATH

for file in ~/.local/share/desktop/migrations/*.sh; do
  touch "$DESKTOP_MIGRATIONS_STATE_PATH/$(basename "$file")"
done
