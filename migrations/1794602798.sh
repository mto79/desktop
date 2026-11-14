#!/usr/bin/env bash

# Claude Code asks before an agent touches a cluster: desktop-agent-hooks adds a PreToolUse
# hook running desktop-agent-cluster-guard, beside any PreToolUse hooks already there, and
# leaves everything else in settings.json as it was. Sessions already running pick it up
# at their next tool call.

~/.local/share/desktop/bin/desktop-agent-hooks
