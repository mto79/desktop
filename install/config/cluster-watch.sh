#!/usr/bin/env bash

# Every cluster asked every two minutes, and a notification when one goes unreachable,
# comes back, loses a node or is signed out; the sidebar's state kept fresh as well.
systemctl --user enable --now desktop-cluster-watch.timer
