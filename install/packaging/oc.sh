#!/usr/bin/env bash

if command -v oc &>/dev/null; then
  echo "oc is already installed. Current version:"
  oc version --client
else
  echo "Installing oc (Openshift Client)"

  # Download oc
  curl -LO "https://mirror.openshift.com/pub/openshift-v4/clients/ocp/latest/openshift-client-linux.tar.gz"

  # Extract the tarball
  tar -xvzf openshift-client-linux.tar.gz

  # Move to /usr/local/bin
  sudo mv oc /usr/local/bin/

  # Make executable
  sudo chmod +x /usr/local/bin/oc

  # Verify installation
  oc version --client
fi
