#!/usr/bin/env bash

# The Vault client. desktop-update-hashicorp does the work, so that an install and every
# update after it agree on which version that is -- see there for why the minor version is
# pinned, and why not HashiCorp's dnf repository, which terraform.sh still adds.
"$DESKTOP_PATH/bin/desktop-update-hashicorp" vault
