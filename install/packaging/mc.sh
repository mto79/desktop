#!/usr/bin/env bash

if command -v mc &>/dev/null; then
  echo "mc is already installed. Current version:"
else
  echo "Installing mc (Minio Client)"

  # Download oc
  curl -LO "https://dl.min.io/client/mc/release/linux-amd64/mc"

  # Move to /usr/local/bin
  sudo mv mc /usr/local/bin/

  # Make executable
  sudo chmod +x /usr/local/bin/mc

fi
