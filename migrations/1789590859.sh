#!/usr/bin/env bash

# desktop-agent-notify is gone: desktop-agent-state now sends the notifications, only when a
# session needs you and you are not already looking at it, and a click jumps to the pane.
# The old hook turned every Claude Code notification into a toast, including the idle
# reminder a minute after each turn, and it would fail on every event once its script was
# removed. desktop-agent-hooks takes it out of settings.json and leaves everything else.

~/.local/share/desktop/bin/desktop-agent-hooks
