#!/usr/bin/env bash

# KeePassXC from Fedora instead of the 2.8.0 snapshot AppImage.
#
# The AppImage was there for 2.8.0's Quick Unlock -- the fingerprint -- when Fedora had
# 2.7.12. Fedora now ships 2.8.0 with Quick Unlock and its polkit policy, so the reasons
# for an AppImage are gone and its costs stay: a password manager in ~/.local/bin that
# anything running as you could replace, which every browser starts to fill a password,
# and which nothing ever updated.
#
# Installs the package, points the copied Hyprland bindings at it, and takes away what
# install/packaging/keepassxc.sh put in place: the AppImage, its keepassxc-cli link, and
# the launcher entry and icons that would otherwise stand in front of Fedora's. Safe to
# re-run; it waits, failing, while the AppImage's KeePassXC is still running.

set -uo pipefail

BIN="${HOME}/.local/bin"
APPIMAGE="${BIN}/KeePassXC.AppImage"
DATA="${XDG_DATA_HOME:-$HOME/.local/share}"
CONFIG="${XDG_CONFIG_HOME:-$HOME/.config}"

if ! rpm -q keepassxc >/dev/null 2>&1; then
  sudo dnf install -y --disablerepo=pgAdmin4 keepassxc || exit 1
fi
echo "  $(rpm -q keepassxc) installed"

# SUPER+X: config/ is copied, so the copy is changed here.
for f in "$CONFIG/hypr/bindings.lua" "$CONFIG/hypr/bindings.conf"; do
  [[ -f $f ]] && grep -q 'KeePassXC\.AppImage' "$f" || continue
  sed -i -e 's|"~/.local/bin/KeePassXC.AppImage"|"uwsm app -- keepassxc"|' \
    -e 's|= ~/.local/bin/KeePassXC.AppImage$|= uwsm app -- keepassxc|' "$f"
  echo "  $f launches keepassxc"
done
command -v hyprctl >/dev/null && hyprctl reload >/dev/null 2>&1

# Browsers reach KeePassXC through the proxy now. KeePassXC writes this itself when it
# starts; done here too, so a browser asking before then finds a program that exists.
for f in "$CONFIG"/{BraveSoftware/Brave-Browser,google-chrome,chromium}/NativeMessagingHosts/org.keepassxc.keepassxc_browser.json; do
  [[ -f $f ]] && grep -q 'KeePassXC\.AppImage' "$f" || continue
  sed -i 's|"path": *"[^"]*KeePassXC\.AppImage"|"path": "/usr/bin/keepassxc-proxy"|' "$f"
  echo "  $f uses keepassxc-proxy"
done

[[ -e $APPIMAGE ]] || { echo "  no AppImage left, nothing more to do"; exit 0; }
if pgrep -f '/\.mount_KeePas[^ ]*/usr/bin/keepassxc$' >/dev/null; then
  echo "  the AppImage's KeePassXC is still running: quit it, then run desktop-migrate again" >&2
  exit 1
fi

# Only what the AppImage installed: the launcher entry when it starts the AppImage, the
# CLI link when it points there.
desktop="$DATA/applications/org.keepassxc.KeePassXC.desktop"
if [[ -f $desktop ]] && grep -q 'KeePassXC\.AppImage' "$desktop"; then
  rm -f "$desktop"
  update-desktop-database "$DATA/applications" 2>/dev/null
  echo "  removed $desktop"
fi
[[ $(readlink "$BIN/keepassxc-cli") == "$APPIMAGE" ]] && rm -f "$BIN/keepassxc-cli" && echo "  removed $BIN/keepassxc-cli"
rm -f "$DATA/icons/keepassxc.png" "$DATA/icons/hicolor/256x256/apps/keepassxc.png" "$BIN/.keepassxc-version"
rm -f "$APPIMAGE"
echo "  removed $APPIMAGE"
