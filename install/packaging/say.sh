#!/usr/bin/env bash

# The voice desktop-say speaks with: the Piper engine in a Python environment of its own
# under ~/.local/share, and one voice beside it, both by exact version and the voice by
# checksum. No sudo. Without it desktop-say still works, with espeak-ng, which is in the
# package list -- so a failure here is a worse voice and not a reason to stop the install.
"$DESKTOP_PATH/bin/desktop-say" --setup || echo "desktop-say: the voice was not installed; espeak-ng will be used" >&2
