#!/usr/bin/env bash
#
# obsidian.sh — Install Obsidian AppImage on Fedora
#
# Downloads the latest official AppImage from Obsidian's GitHub releases,
# installs it to ~/.local/bin, creates a .desktop entry, and sets up
# a systemd user timer to check for updates daily.
#
# Usage:
#   ./obsidian.sh           # full install + auto-update timer
#   ./obsidian.sh update    # just check for updates now
#

set -euo pipefail

GITHUB_API="https://api.github.com/repos/obsidianmd/obsidian-releases/releases/latest"
APPIMAGE_DIR="${HOME}/.local/bin"
APPIMAGE_PATH="${APPIMAGE_DIR}/Obsidian.AppImage"
VERSION_FILE="${APPIMAGE_DIR}/.obsidian-version"
DESKTOP_DIR="${HOME}/.local/share/applications"
ICON_DIR="${HOME}/.local/share/icons"
SYSTEMD_DIR="${HOME}/.config/systemd/user"

info() { printf '\033[1;34m[INFO]\033[0m  %s\n' "$*"; }
ok() { printf '\033[1;32m[OK]\033[0m    %s\n' "$*"; }
err() { printf '\033[1;31m[ERR]\033[0m   %s\n' "$*" >&2; }

get_latest_version() {
  local response
  response=$(curl -fsSL "$GITHUB_API")
  echo "$response" | grep -m1 '"tag_name"' | sed 's/.*"v\?\(.*\)".*/\1/'
}

get_installed_version() {
  if [[ -f "$VERSION_FILE" ]]; then
    cat "$VERSION_FILE"
  else
    echo "none"
  fi
}

download_appimage() {
  local version="$1"
  local url="https://github.com/obsidianmd/obsidian-releases/releases/download/v${version}/Obsidian-${version}.AppImage"

  info "Downloading Obsidian v${version}..."
  curl -fSL -o "${APPIMAGE_PATH}.tmp" "$url"
  mv -f "${APPIMAGE_PATH}.tmp" "$APPIMAGE_PATH"
  chmod +x "$APPIMAGE_PATH"
  echo "$version" >"$VERSION_FILE"
  ok "Obsidian v${version} installed at ${APPIMAGE_PATH}"
}

install_fuse() {
  if command -v fusermount3 &>/dev/null || command -v fusermount &>/dev/null; then
    return
  fi
  info "Installing FUSE (required for AppImage)..."
  sudo dnf install -y fuse fuse-libs
}

create_desktop_entry() {
  mkdir -p "$DESKTOP_DIR" "$ICON_DIR"

  info "Downloading Obsidian icon..."
  curl -fSL -o "${ICON_DIR}/obsidian.png" \
    "https://raw.githubusercontent.com/obsidianmd/obsidian-releases/master/obsidian.png" 2>/dev/null || true

  cat >"${DESKTOP_DIR}/obsidian.desktop" <<EOF
[Desktop Entry]
Name=Obsidian
Comment=Knowledge base and note-taking
Exec=${APPIMAGE_PATH} %u
Icon=${ICON_DIR}/obsidian.png
Type=Application
Categories=Office;TextEditor;
MimeType=x-scheme-handler/obsidian;
StartupWMClass=obsidian
EOF
  update-desktop-database "$DESKTOP_DIR" 2>/dev/null || true
  ok "Desktop entry created."
}

create_update_script() {
  local script_path="${APPIMAGE_DIR}/obsidian-update.sh"

  cat >"$script_path" <<'SCRIPT'
#!/usr/bin/env bash
set -euo pipefail

GITHUB_API="https://api.github.com/repos/obsidianmd/obsidian-releases/releases/latest"
APPIMAGE_DIR="${HOME}/.local/bin"
APPIMAGE_PATH="${APPIMAGE_DIR}/Obsidian.AppImage"
VERSION_FILE="${APPIMAGE_DIR}/.obsidian-version"

response=$(curl -fsSL "$GITHUB_API")
latest=$(echo "$response" | grep -m1 '"tag_name"' | sed 's/.*"v\?\(.*\)".*/\1/')
installed="none"
[[ -f "$VERSION_FILE" ]] && installed=$(cat "$VERSION_FILE")

if [[ "$latest" == "$installed" ]]; then
    echo "[obsidian-update] Already on v${installed}, nothing to do."
    exit 0
fi

echo "[obsidian-update] Updating Obsidian: v${installed} -> v${latest}"
url="https://github.com/obsidianmd/obsidian-releases/releases/download/v${latest}/Obsidian-${latest}.AppImage"
curl -fSL -o "${APPIMAGE_PATH}.tmp" "$url"
mv -f "${APPIMAGE_PATH}.tmp" "$APPIMAGE_PATH"
chmod +x "$APPIMAGE_PATH"
echo "$latest" > "$VERSION_FILE"
echo "[obsidian-update] Updated to v${latest}."

# Desktop notification if possible
if command -v notify-send &>/dev/null; then
    notify-send "Obsidian Updated" "Obsidian has been updated to v${latest}." \
        --icon="${HOME}/.local/share/icons/obsidian.png" 2>/dev/null || true
fi
SCRIPT
  chmod +x "$script_path"
  ok "Update script created at ${script_path}"
}

setup_systemd_timer() {
  mkdir -p "$SYSTEMD_DIR"

  cat >"${SYSTEMD_DIR}/obsidian-update.service" <<EOF
[Unit]
Description=Check for Obsidian AppImage updates

[Service]
Type=oneshot
ExecStart=${APPIMAGE_DIR}/obsidian-update.sh
Environment=DISPLAY=:0
EOF

  cat >"${SYSTEMD_DIR}/obsidian-update.timer" <<EOF
[Unit]
Description=Daily Obsidian update check

[Timer]
OnCalendar=daily
RandomizedDelaySec=1h
Persistent=true

[Install]
WantedBy=timers.target
EOF

  systemctl --user daemon-reload
  systemctl --user enable --now obsidian-update.timer
  ok "Systemd user timer enabled (daily update check)."
  info "Check timer status:  systemctl --user status obsidian-update.timer"
  info "Force update now:    systemctl --user start obsidian-update.service"
}

do_update() {
  local latest installed
  latest=$(get_latest_version)
  installed=$(get_installed_version)

  if [[ "$latest" == "$installed" ]]; then
    ok "Already on the latest version (v${installed})."
    return 0
  fi

  info "Update available: v${installed} -> v${latest}"
  download_appimage "$latest"
}

do_install() {
  info "Installing Obsidian AppImage on Fedora..."
  echo ""

  mkdir -p "$APPIMAGE_DIR"

  install_fuse

  local latest
  latest=$(get_latest_version)
  download_appimage "$latest"

  create_desktop_entry
  create_update_script
  setup_systemd_timer

  echo ""
  ok "Installation complete!"
  info "Launch:             ${APPIMAGE_PATH}"
  info "Or find 'Obsidian' in your application menu."
  info "Auto-updates:       systemd timer runs daily"
  info "Manual update:      ${APPIMAGE_DIR}/obsidian-update.sh"
}

case "${1:-install}" in
install)
  do_install
  ;;
update)
  do_update
  ;;
*)
  err "Unknown command: ${1}"
  echo "Usage: $0 [install|update]"
  exit 1
  ;;
esac
