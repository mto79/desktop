#!/usr/bin/env bash

# Dropping the Fedora keepassxc RPM in favour of the 2.8.0 snapshot AppImage also took
# /usr/bin/keepassxc-cli with it, and nothing put it back -- so `keepassxc-cli` has been
# missing on every machine installed since. The binary was never gone: it sits inside
# the AppImage, and AppRun dispatches to it when argv[0] names it. A symlink is the
# whole fix. install/packaging/keepassxc.sh now makes it; this is for machines that
# already ran the old one.

set -uo pipefail

APPIMAGE="${HOME}/.local/bin/KeePassXC.AppImage"
CLI="${HOME}/.local/bin/keepassxc-cli"

if [[ ! -x $APPIMAGE ]]; then
  echo "  no KeePassXC AppImage on this machine, nothing to do"
  exit 0
fi

ln -sfn "$APPIMAGE" "$CLI"
echo "  linked $CLI -> $APPIMAGE"
"$CLI" --version
