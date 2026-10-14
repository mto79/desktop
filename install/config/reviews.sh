#!/usr/bin/env bash

# desktop-reviews every five minutes: a popup when a merge or pull request starts waiting
# for you, on every host glab and gh are logged in to.
systemctl --user enable --now desktop-reviews.timer
