#!/usr/bin/env bash

# The clusters' watch, on machines installed before it existed. config/ is copied at install
# only, so the timer's units are copied here; on a fresh machine
# install/config/cluster-watch.sh enables it.

SRC="$HOME/.local/share/desktop/config/systemd/user"
DEST="$HOME/.config/systemd/user"
mkdir -p "$DEST"
cp "$SRC/desktop-cluster-watch.service" "$SRC/desktop-cluster-watch.timer" "$DEST/"
systemctl --user daemon-reload
systemctl --user enable --now desktop-cluster-watch.timer
echo "  the clusters are watched every two minutes"
