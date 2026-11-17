#!/usr/bin/env bash

# Your merge requests' pipelines asked every minute: the bar's GitLab mark, and a popup
# when one finishes. Nothing is asked until glab is logged in somewhere.
systemctl --user enable --now desktop-pipelines.timer
