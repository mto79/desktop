#!/usr/bin/env bash
#
# keepassxc.sh — Install the KeePassXC AppImage on Fedora
#
# We track the 2.8.0 snapshot rather than Fedora's keepassxc RPM (2.7.12),
# so this deliberately does NOT install the package -- having both left
# Hyprland launching /usr/bin/keepassxc while the app menu launched the
# AppImage. Installs to ~/.local/bin, writes a .desktop entry, symlinks
# keepassxc-cli back onto PATH (the RPM used to provide it), and points
# the browser native-messaging manifests at the AppImage (which serves as
# its own proxy; the separate keepassxc-proxy binary links against system
# Qt that is not installed once the RPM is gone).
#
# Usage:
#   ./keepassxc.sh           # full install
#   ./keepassxc.sh update    # re-download the pinned snapshot
#

set -euo pipefail

# 2.8.0 is not a GitHub release -- snapshots are published as numbered CI
# builds at snapshot.keepassxc.org, so we resolve the newest one at run time.
VERSION="2.8.0-snapshot"
SNAPSHOT_INDEX="https://snapshot.keepassxc.org"
APPIMAGE_NAME="KeePassXC-${VERSION}-x86_64.AppImage"
APPIMAGE_DIR="${HOME}/.local/bin"
APPIMAGE_PATH="${APPIMAGE_DIR}/KeePassXC.AppImage"
CLI_PATH="${APPIMAGE_DIR}/keepassxc-cli"
VERSION_FILE="${APPIMAGE_DIR}/.keepassxc-version"
DESKTOP_DIR="${HOME}/.local/share/applications"
ICON_DIR="${HOME}/.local/share/icons"

info() { printf '\033[1;34m[INFO]\033[0m  %s\n' "$*"; }
ok() { printf '\033[1;32m[OK]\033[0m    %s\n' "$*"; }
err() { printf '\033[1;31m[ERR]\033[0m   %s\n' "$*" >&2; }

install_fuse() {
  if command -v fusermount3 &>/dev/null || command -v fusermount &>/dev/null; then
    return
  fi
  info "Installing FUSE (required for AppImage)..."
  sudo dnf install -y fuse fuse-libs
}

remove_rpm() {
  if rpm -q keepassxc &>/dev/null; then
    info "Removing the Fedora keepassxc RPM so only the AppImage remains..."
    sudo dnf remove -y keepassxc
    ok "RPM removed."
  fi
}

latest_build() {
  curl -fsSL "${SNAPSHOT_INDEX}/" |
    grep -oP 'href="build-\K[0-9]+' | sort -n | tail -1
}

download_appimage() {
  local build url
  build=$(latest_build)
  if [[ -z "$build" ]]; then
    err "Could not determine the latest snapshot build from ${SNAPSHOT_INDEX}"
    exit 1
  fi
  url="${SNAPSHOT_INDEX}/build-${build}/${APPIMAGE_NAME}"

  info "Downloading KeePassXC ${VERSION} (build ${build})..."
  curl -fSL -o "${APPIMAGE_PATH}.tmp" "$url"

  # Snapshots ship a DIGEST file; refuse a corrupt or truncated download.
  local expected
  if expected=$(curl -fsSL "${url}.DIGEST" 2>/dev/null | grep -oP '^[0-9a-f]{64}'); then
    local actual
    actual=$(sha256sum "${APPIMAGE_PATH}.tmp" | cut -d' ' -f1)
    if [[ "$expected" != "$actual" ]]; then
      rm -f "${APPIMAGE_PATH}.tmp"
      err "SHA-256 mismatch for ${APPIMAGE_NAME} -- refusing to install."
      exit 1
    fi
    ok "SHA-256 verified."
  else
    info "No DIGEST published for this build; skipping checksum."
  fi

  mv -f "${APPIMAGE_PATH}.tmp" "$APPIMAGE_PATH"
  chmod +x "$APPIMAGE_PATH"
  echo "${VERSION} (build ${build})" >"$VERSION_FILE"
  ok "KeePassXC ${VERSION} installed at ${APPIMAGE_PATH}"
}

link_cli() {
  # keepassxc-cli lives inside the AppImage, but AppRun only dispatches to it when the
  # name it was invoked as says so -- `KeePassXC.AppImage cli` or an argv[0] of
  # keepassxc-cli. Dropping the RPM took /usr/bin/keepassxc-cli with it, so a symlink
  # named after the binary is what puts the CLI back on PATH.
  ln -sfn "$APPIMAGE_PATH" "$CLI_PATH"
  ok "keepassxc-cli linked at ${CLI_PATH}"
}

create_desktop_entry() {
  mkdir -p "$DESKTOP_DIR" "$ICON_DIR"

  info "Extracting icon from AppImage..."
  local tmpdir
  tmpdir=$(mktemp -d)
  pushd "$tmpdir" &>/dev/null
  "${APPIMAGE_PATH}" --appimage-extract &>/dev/null || true

  local icon="" root="$tmpdir/squashfs-root"
  for size in 512x512 256x256 128x128 64x64 48x48 32x32; do
    icon=$(find "$root" -path "*/hicolor/${size}/apps/*keepassxc*.png" -type f 2>/dev/null | head -1)
    [[ -n "$icon" ]] && break
  done
  if [[ -z "$icon" ]] && [[ -f "$root/.DirIcon" ]]; then
    icon="$root/.DirIcon"
  fi

  if [[ -n "$icon" ]]; then
    cp "$icon" "${ICON_DIR}/keepassxc.png"
    ok "Icon extracted ($(basename "$icon"))."
  else
    err "Could not extract icon from AppImage."
  fi

  popd &>/dev/null
  rm -rf "$tmpdir"

  cat >"${DESKTOP_DIR}/org.keepassxc.KeePassXC.desktop" <<EOF
[Desktop Entry]
Name=KeePassXC
GenericName=Password Manager
Comment=Community-driven port of the Windows application "KeePass Password Safe"
Exec=${APPIMAGE_PATH} %f
TryExec=${APPIMAGE_PATH}
Icon=${ICON_DIR}/keepassxc.png
Type=Application
Categories=Utility;Security;Qt;
MimeType=application/x-keepass2;
StartupWMClass=keepassxc
SingleMainWindow=true
EOF
  update-desktop-database "$DESKTOP_DIR" 2>/dev/null || true
  ok "Desktop entry created."
}

install_polkit_policy() {
  # Quick Unlock authenticates through polkit, and polkit only honours an action whose
  # .policy file is registered system-wide. The Fedora RPM used to install it; nothing
  # installs it for an AppImage, so the fingerprint prompt asks polkit to authorise an
  # action it has never heard of and the unlock is refused. The agent that draws that
  # prompt is hyprpolkitagent, in install/desktop-base.packages.
  local policy="org.keepassxc.KeePassXC.policy"
  local tmpdir src

  tmpdir=$(mktemp -d)
  pushd "$tmpdir" &>/dev/null
  "${APPIMAGE_PATH}" --appimage-extract "usr/share/polkit-1/actions/${policy}" &>/dev/null || true
  popd &>/dev/null

  src="${tmpdir}/squashfs-root/usr/share/polkit-1/actions/${policy}"
  if [[ -f "$src" ]]; then
    sudo install -D -m 0644 "$src" "/usr/share/polkit-1/actions/${policy}"
    ok "Polkit policy installed (Quick Unlock)."
  else
    err "No polkit policy in the AppImage -- Quick Unlock will not authenticate."
  fi
  rm -rf "$tmpdir"
}

link_browser_integration() {
  # The AppImage answers native-messaging calls itself, so both browsers point
  # straight at it. Keeps working across updates because the path is stable.
  local manifest_dirs=(
    "${HOME}/.config/BraveSoftware/Brave-Browser/NativeMessagingHosts"
    "${HOME}/.config/google-chrome/NativeMessagingHosts"
  )
  for dir in "${manifest_dirs[@]}"; do
    local manifest="${dir}/org.keepassxc.keepassxc_browser.json"
    [[ -f "$manifest" ]] || continue
    sed -i "s|\"path\": \".*\"|\"path\": \"${APPIMAGE_PATH}\"|" "$manifest"
    ok "Browser manifest updated: ${manifest}"
  done
}

do_install() {
  info "Installing KeePassXC ${VERSION} AppImage on Fedora..."
  echo ""
  mkdir -p "$APPIMAGE_DIR"
  install_fuse
  remove_rpm
  download_appimage
  link_cli
  create_desktop_entry
  install_polkit_policy
  link_browser_integration
  echo ""
  ok "Installation complete!"
  info "Launch:  ${APPIMAGE_PATH}  (SUPER+X, and autostarted on workspace 4)"
}

case "${1:-install}" in
install)
  do_install
  ;;
update)
  download_appimage
  link_cli
  create_desktop_entry
  install_polkit_policy
  ;;
*)
  err "Unknown command: ${1}"
  echo "Usage: $0 [install|update]"
  exit 1
  ;;
esac
