#!/usr/bin/env bash

# Detect OS
OS="$(uname | tr '[:upper:]' '[:lower:]')"

# Detect architecture
ARCH="$(uname -m)"
case "$ARCH" in
x86_64) ARCH="amd64" ;;
aarch64 | arm64) ARCH="arm64" ;;
*)
  echo "Unsupported architecture: $ARCH"
  exit 1
  ;;
esac

# Kubectl version (latest stable)
KUBECTL_VERSION=$(curl -L -s https://dl.k8s.io/release/stable.txt)

echo "Installing kubectl $KUBECTL_VERSION for $OS/$ARCH ..."

# Download kubectl
curl -LO "https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/${OS}/${ARCH}/kubectl"

# Download checksum and verify
curl -LO "https://dl.k8s.io/${KUBECTL_VERSION}/bin/${OS}/${ARCH}/kubectl.sha256"
echo "$(cat kubectl.sha256) kubectl" | sha256sum --check

# Make executable
chmod +x kubectl

# Move to /usr/local/bin
sudo mv kubectl /usr/local/bin/

# Verify installation
kubectl version --client

# Create ~/.kube if it doesn't exist
mkdir -p ~/.kube
mkdir -p ~/.kube/clusters/
rm -rf kubectl.sha256

echo "kubectl installed successfully! ~/.kube directory is ready."
