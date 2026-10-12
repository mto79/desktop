#!/usr/bin/env bash

# bluetoothd crashed and stayed down: the unit Fedora ships does not restart it. The
# installer now adds a drop-in that does, and a machine installed earlier gets it here.
# The script is the installer's own, which writes the file only when it is not already
# the one wanted.
source "$HOME/.local/share/desktop/install/config/hardware/bluetooth.sh"
