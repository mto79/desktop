#!/usr/bin/env bash

# The OpenShift client. desktop-update-oc does the work, so that an install and every
# update after it agree on which version that is -- see there for why it is pinned.
"$DESKTOP_PATH/bin/desktop-update-oc"
