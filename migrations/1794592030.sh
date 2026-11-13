#!/usr/bin/env bash

# Claude Code sessions start with Remote Control on, so an agent running in tmux can be
# followed and answered from the Claude app. desktop-agent-hooks sets
# remoteControlAtStartup in settings.json when it is not there, and leaves a false alone.

~/.local/share/desktop/bin/desktop-agent-hooks
