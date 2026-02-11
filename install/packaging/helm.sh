#!/usr/bin/env bash

set -e
# Function to extract pure numeric version (major.minor.patch)
extract_version() {
    echo "$1" | grep -oE '[0-9]+\.[0-9]+\.[0-9]+'
}

# Compare versions: returns 0 if $1 > $2
version_gt() {
    [ "$(printf '%s\n' "$1" "$2" | sort -V | tail -n1)" = "$1" ] && [ "$1" != "$2" ]
}

echo "Checking installed Helm version..."
if command -v helm &>/dev/null; then
    INSTALLED_VERSION_RAW=$(helm version --short 2>/dev/null)
    INSTALLED_VERSION=$(extract_version "$INSTALLED_VERSION_RAW")
    echo "Installed Helm version: $INSTALLED_VERSION"
else
    INSTALLED_VERSION="0.0.0"
    echo "Helm is not installed."
fi

echo "Checking latest Helm version..."
LATEST_VERSION_RAW=$(curl -s https://api.github.com/repos/helm/helm/releases/latest | grep '"tag_name":' | sed -E 's/.*"v([^"]+)".*/\1/')
LATEST_VERSION=$(extract_version "$LATEST_VERSION_RAW")
echo "Latest Helm version: $LATEST_VERSION"

if version_gt "$LATEST_VERSION" "$INSTALLED_VERSION"; then
    echo "A newer version of Helm is available. Installing v$LATEST_VERSION..."

    sudo dnf install -y curl tar gzip

    curl -LO https://get.helm.sh/helm-v${LATEST_VERSION}-linux-amd64.tar.gz
    tar -zxvf helm-v${LATEST_VERSION}-linux-amd64.tar.gz
    sudo mv linux-amd64/helm /usr/local/bin/helm
    rm -rf linux-amd64 helm-v${LATEST_VERSION}-linux-amd64.tar.gz

    echo "Helm v${LATEST_VERSION} installed successfully!"
    helm version
else
    echo "You already have the latest Helm version ($INSTALLED_VERSION). No action needed."
fi
