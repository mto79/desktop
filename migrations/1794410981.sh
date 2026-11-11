#!/usr/bin/env bash

# Screen time on the dashboard: a timer that counts the minutes the screen is in use, and
# the hypridle listener that tells it when the screen has been left alone. Through
# desktop-refresh-hypridle, which keeps a copy of the hypridle.conf it replaces.
cp ~/.local/share/desktop/config/systemd/user/desktop-screentime.{service,timer} ~/.config/systemd/user/
systemctl --user daemon-reload
systemctl --user enable --now desktop-screentime.timer
desktop-refresh-hypridle
