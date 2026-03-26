#!/usr/bin/env bash

set -euo pipefail

# --- Variables ---
ZOOM_URL="https://zoom.us/client/latest/zoom_x86_64.rpm"
DOWNLOAD_DIR="$HOME/Downloads"
RPM_FILE="$DOWNLOAD_DIR/zoom_x86_64.rpm"
SCALE_FACTOR=2 # Adjust this for your screen (1.5, 2, etc.)

# --- Download Zoom ---
echo "==> Creating download directory..."
mkdir -p "$DOWNLOAD_DIR"

echo "==> Downloading latest Zoom RPM..."
curl -L "$ZOOM_URL" -o "$RPM_FILE"

# --- Install Zoom ---
echo "==> Installing Zoom..."
sudo dnf install -y "$RPM_FILE"

# --- Cleanup ---
echo "==> Removing downloaded RPM..."
rm -f "$RPM_FILE"

# --- Configure HiDPI Scaling ---
DESKTOP_FILE="/usr/share/applications/Zoom.desktop"
if [ -f "$DESKTOP_FILE" ]; then
  echo "==> Setting HiDPI scaling (QT_SCALE_FACTOR=$SCALE_FACTOR) in desktop launcher..."
  # Make a backup first
  sudo cp "$DESKTOP_FILE" "${DESKTOP_FILE}.bak"
  # Replace the Exec line
  sudo sed -i "s|^Exec=/usr/bin/zoom %U|Exec=env QT_SCALE_FACTOR=$SCALE_FACTOR /usr/bin/zoom %U|" "$DESKTOP_FILE"
fi

echo "✅ Zoom installation complete!"
echo "You can launch Zoom from the menu or by typing 'zoom' in terminal."
echo "HiDPI scaling is set to $SCALE_FACTOR. Adjust in the script if needed."
