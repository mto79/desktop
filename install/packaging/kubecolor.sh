#!/usr/bin/env bash

# kubecolor, which colours what kubectl and oc print (config/fish/conf.d/kubecolor.fish puts
# it in front of both), from upstream's newest release. desktop-update-releases does the work
# and checks the download against the digest GitHub publishes for it.
"$DESKTOP_PATH/bin/desktop-update-releases" kubecolor
