#!/usr/bin/env bash

# The OpenBao client, bao. desktop-update-openbao does the work, so that an install and every
# update after it agree on which version that is -- see there for why the minor version is
# pinned, and why not Fedora's openbao package.
"$DESKTOP_PATH/bin/desktop-update-openbao"
