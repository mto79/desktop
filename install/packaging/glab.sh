#!/usr/bin/env bash

echo "Downloading and installing glab CLI..."

# Download the latest glab release for Linux (amd64)
GLAB_LATEST=$(curl -s https://api.github.com/repos/profclems/glab/releases/latest | grep "browser_download_url.*linux_amd64.rpm" | cut -d '"' -f 4)

if [[ -z "$GLAB_LATEST" ]]; then
  echo "Error: Could not find the latest glab release."
  exit 1
fi

echo "Latest glab release: $GLAB_LATEST"

# Download the RPM
curl -L -o glab.rpm "$GLAB_LATEST"

# Install using dnf
sudo dnf install -y ./glab.rpm

# Clean up
rm -f glab.rpm

echo "Verifying glab installation..."
glab --version

echo "glab installation complete!"
