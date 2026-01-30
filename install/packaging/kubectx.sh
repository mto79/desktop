#!/usr/bin/env bash

# set -euo pipefail

# -------- helper functions --------
err() {
  echo "ERROR: $*" >&2
}

command_exists() {
  command -v "$1" >/dev/null 2>&1
}

safe_ln() {
  local target="$1"
  local link="$2"

  if [ -L "$link" ]; then
    echo "Symlink $link already exists, skipping"
  elif [ -e "$link" ]; then
    echo "File $link exists but is not a symlink, skipping"
  else
    sudo ln -s "$target" "$link"
    echo "Created symlink $link -> $target"
  fi
}

# -------- variables --------
KUBECTX_DIR="/opt/kubectx"
BIN_DIR="/usr/local/bin"

# -------- clone or update --------
if [ -d "$KUBECTX_DIR" ]; then
  echo "Updating kubectx/kubens in $KUBECTX_DIR..."
  sudo git -C "$KUBECTX_DIR" pull --ff-only || echo "Failed to update, skipping"
else
  echo "Cloning kubectx/kubens into $KUBECTX_DIR..."
  sudo git clone https://github.com/ahmetb/kubectx "$KUBECTX_DIR"
fi

# -------- install symlinks --------
safe_ln "$KUBECTX_DIR/kubectx" "$BIN_DIR/kubectx"
safe_ln "$KUBECTX_DIR/kubens" "$BIN_DIR/kubens"

# -------- install fish completions --------
FISH_COMPLETIONS_DIR="$HOME/.config/fish/completions"
mkdir -p "$FISH_COMPLETIONS_DIR"

safe_ln "$KUBECTX_DIR/completion/kubectx.fish" "$FISH_COMPLETIONS_DIR/kubectx.fish"
safe_ln "$KUBECTX_DIR/completion/kubens.fish" "$FISH_COMPLETIONS_DIR/kubens.fish"

# -------- ensure kube clusters dir exists --------
mkdir -p "$HOME/.kube/clusters"

echo "kubectx and kubens installed/updated successfully!"

# if [ -d /opt/kubectx ]; then
#   sudo git -C /opt/kubectx pull
# else
#   sudo git clone https://github.com/ahmetb/kubectx /opt/kubectx
#   ln -s /opt/kubectx/kubectx /usr/local/bin/kubectx
#   ln -s /opt/kubectx/kubens /usr/local/bin/kubens
#
#   mkdir -p ~/.config/fish/completions
#   ln -s /opt/kubectx/completion/kubectx.fish ~/.config/fish/completions/
#   ln -s /opt/kubectx/completion/kubens.fish ~/.config/fish/completions/
#
#   mkdir -p ~/.kube/clusters/
# fi
