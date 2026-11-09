#!/usr/bin/env bash

# kubectl. desktop-update-kubectl does the work, so that an install and every update after
# it agree on which version that is -- see there for why the minor version is pinned.
"$DESKTOP_PATH/bin/desktop-update-kubectl"

mkdir -p ~/.kube/clusters
# ~/.kube holds cluster tokens; it starts out owner-only and every desktop-update keeps it so.
"$DESKTOP_PATH/bin/desktop-update-secrets"
