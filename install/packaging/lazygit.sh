#!/usr/bin/env bash

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
x86_64) ARCH="x86_64" ;;
aarch64 | arm64) ARCH="arm64" ;;
*)
  err "Unsupported architecture: $ARCH"
  ;;
esac

# -------- latest LazyGit version --------
REPO="jesseduffield/lazygit"
LATEST_VERSION="$(curl -fsSL "https://api.github.com/repos/$REPO/releases/latest" | grep -Po '"tag_name": "\K.*?(?=")')"
BIN_DIR="/usr/local/bin"
BIN_PATH="${BIN_DIR}/lazygit"

echo "Target LazyGit version: ${LATEST_VERSION}"
echo "Platform: ${OS}/${ARCH}"

# -------- check existing lazygit --------
if command_exists lazygit; then
  CURRENT_VERSION="$(lazygit --version | awk '{print $2}')"
  if [[ "$CURRENT_VERSION" == "${LATEST_VERSION#v}" ]]; then
    echo "LazyGit ${CURRENT_VERSION} is already installed. Nothing to do."
    exit 0
  fi
  echo "LazyGit ${CURRENT_VERSION} found, upgrading to ${LATEST_VERSION#v}..."
else
  echo "LazyGit not found, installing..."
fi

# -------- download --------
TMPDIR="$(mktemp -d -t lazygit-install.XXXXXX)" || err "mktemp failed"
trap 'rm -rf "$TMPDIR"' EXIT

cd "$TMPDIR" || err "cd to temp dir failed"
echo "Using temporary directory: $TMPDIR"

DOWNLOAD_URL="https://github.com/$REPO/releases/download/$LATEST_VERSION/lazygit_${LATEST_VERSION#v}_Linux_${ARCH}.tar.gz"
echo "Downloading LazyGit from $DOWNLOAD_URL"
curl -fsSL -o lazygit.tar.gz "$DOWNLOAD_URL"

# -------- extract --------
tar -xzf lazygit.tar.gz || err "Failed to extract LazyGit"
chmod +x lazygit

echo "Move lazygit to ${BIN_DIR}"
sudo mv lazygit "$BIN_PATH"

# -------- verify installation --------
echo "Verify LazyGit installation"
lazygit --version
