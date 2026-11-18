#!/usr/bin/env bash

# The printers within reach asked every two minutes: the bar's printer, and a popup when
# one has a problem or runs low on ink.
systemctl --user enable --now desktop-printers.timer
