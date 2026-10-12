#!/usr/bin/env bash

# Install k9s on a machine that was set up before it was in the package list.
#
# k9s is the terminal UI for looking around inside a cluster -- pods, logs, events -- where
# oc is for asking one question at a time. It works on whatever kubeconfig it is given, so
# it does no logging in of its own; `ocl -k` hands it a kubeconfig holding one cluster.

if ! rpm -q k9s >/dev/null 2>&1; then
  # --disablerepo because pgAdmin4's repo fails GPG verification, and one bad repo stops
  # a transaction that has nothing to do with it.
  sudo dnf install -y --disablerepo=pgAdmin4 k9s || exit 1
  echo "  installed k9s $(rpm -q --qf '%{VERSION}' k9s)"
else
  echo "  k9s was already installed"
fi
