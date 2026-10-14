#!/usr/bin/env bash

# The review-request popups, on machines installed before they existed. config/ is copied
# at install only, so the timer's units are copied here; tea, which asks Forgejo, is
# installed by the same script a fresh install runs.

SRC="$HOME/.local/share/desktop/config/systemd/user"
DEST="$HOME/.config/systemd/user"
mkdir -p "$DEST"
cp "$SRC/desktop-reviews.service" "$SRC/desktop-reviews.timer" "$DEST/"
systemctl --user daemon-reload
systemctl --user enable --now desktop-reviews.timer
echo "  merge and pull requests waiting for you pop up, checked every five minutes"

bash "$HOME/.local/share/desktop/install/packaging/tea.sh"
