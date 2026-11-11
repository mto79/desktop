#!/usr/bin/env bash

# desktop-screentime once a minute: the screen time on the dashboard's start page. It
# counts only while hypridle has not marked the screen idle -- see config/hypr/hypridle.conf.
systemctl --user enable --now desktop-screentime.timer
