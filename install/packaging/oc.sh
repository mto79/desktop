#!/usr/bin/env bash

echo "Installing oc (Openshift Client)"

# Download kubectl
curl -LO "https://mirror.openshift.com/pub/openshift-v4/clients/ocp/latest/openshift-client-linux.tar.gz"

# Download checksum and verify

# Extract the tarball
tar -xvzf openshift-client-linux.tar.gz

# Move to /usr/local/bin
sudo mv oc /usr/local/bin/

# Make executable
sudo chmod +x /usr/local/bin/oc

# Verify installation
oc version --client
