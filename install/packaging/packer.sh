#!/usr/bin/env bash

# Packer, for building the golden images. desktop-update-hashicorp does the work, so that an
# install and every update after it agree on which version that is -- see there for why the
# minor version is pinned.
"$DESKTOP_PATH/bin/desktop-update-hashicorp" packer
