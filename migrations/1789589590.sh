#!/usr/bin/env bash

# Wire Claude Code's hooks to desktop-agent-state on machines installed before it existed,
# so the AI panel and the bar can tell a session that is waiting on you from one that is
# working. install/config/config.sh does this for a fresh install; nothing re-runs that on
# an existing machine, and settings.json is merged rather than copied, so a migration is
# the only way it arrives here.
#
# desktop-agent-hooks only adds what is missing, so this is safe to run again. Sessions
# already open pick the hooks up and start reporting from their next event.

~/.local/share/desktop/bin/desktop-agent-hooks
