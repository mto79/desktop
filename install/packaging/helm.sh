#!/usr/bin/env bash

# helm, from upstream's newest release. desktop-update-releases does the work and checks the
# download against its published checksum, so an install and every update agree.
"$DESKTOP_PATH/bin/desktop-update-releases" helm
