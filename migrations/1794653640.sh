#!/usr/bin/env bash

# codex and opencode report what they are doing, as Claude Code does, and ask before they
# touch a cluster. desktop-agent-hooks writes codex's hooks.json and its rules in
# ~/.codex/rules/, opencode's plugin and its permissions, leaving every entry of your own in
# those files where it was. codex asks once, when it next starts, to trust the new hooks.

~/.local/share/desktop/bin/desktop-agent-hooks
