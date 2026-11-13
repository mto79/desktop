#!/usr/bin/env bash

# talosctl, for the Talos clusters desktop-cluster reaches (the talos kind in
# clusters.conf), from upstream's newest release. desktop-update-releases does the work and
# checks the download against the digest GitHub publishes for it, so an install and every
# update agree.
"$DESKTOP_PATH/bin/desktop-update-releases" talosctl
