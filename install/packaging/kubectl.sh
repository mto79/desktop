#!/usr/bin/env bash
#set -euo pipefail

# -------- helpers --------
err() {
  echo "ERROR: $*" >&2
  exit 1
}

command_exists() {
  command -v "$1" >/dev/null 2>&1
}

# -------- detect OS --------
OS="$(uname | tr '[:upper:]' '[:lower:]')"
case "$OS" in
linux | darwin) ;;
*)
  err "Unsupported OS: $OS"
  ;;
esac

# -------- detect architecture --------
ARCH="$(uname -m)"
case "$ARCH" in
x86_64) ARCH="amd64" ;;
aarch64 | arm64) ARCH="arm64" ;;
*)
  err "Unsupported architecture: $ARCH"
  ;;
esac

# -------- desired kubectl version --------
KUBECTL_VERSION="$(curl -fsSL https://dl.k8s.io/release/stable.txt)"
BIN_DIR="/usr/local/bin"
BIN_PATH="${BIN_DIR}/kubectl"

echo "Target kubectl version: ${KUBECTL_VERSION}"
echo "Platform: ${OS}/${ARCH}"

# -------- check existing kubectl --------
if command_exists kubectl; then
  CURRENT_VERSION="$(kubectl version --client -o json | jq -r '.clientVersion.gitVersion')"

  if [[ "$CURRENT_VERSION" == "$KUBECTL_VERSION" ]]; then
    echo "kubectl ${CURRENT_VERSION} is already installed. Nothing to do."
  fi

  echo "kubectl ${CURRENT_VERSION} found, upgrading to ${KUBECTL_VERSION}..."
else
  echo "kubectl not found, installing..."
fi

# -------- download --------
TMPDIR="$(mktemp -d -t kubectl-install.XXXXXX)" || err "mktemp failed"
trap 'rm -rf "$TMPDIR"' EXIT

cd "$TMPDIR" || err "cd to temp dir failed"
echo "Using temporary directory: $TMPDIR"

curl -fsSLO "https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/${OS}/${ARCH}/kubectl"
curl -fsSLO "https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/${OS}/${ARCH}/kubectl.sha256"

# -------- verify checksum --------
echo "$(cat kubectl.sha256)  kubectl" | sha256sum --check --status || err "Checksum verification failed"

echo "Make kubectl executable"
chmod +x kubectl

echo "Move kubectl to /usr/local/bin"
sudo mv kubectl /usr/local/bin/

echo "Verify kubectl installation"
kubectl version --client

# Create ~/.kube if it doesn't exist
mkdir -p ~/.kube
mkdir -p ~/.kube/clusters/

echo "kubectl installed successfully! ~/.kube directory is ready."
