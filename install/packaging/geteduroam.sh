#!/usr/bin/env bash

# geteduroam: sets up eduroam from your institution's own profile, certificates included,
# as a NetworkManager connection. Run it from the launcher, or as geteduroam-gui.
#
# Not in Fedora. The project publishes an RPM per release, and that RPM is not signed, so
# what stands in for a signature is the checksum written down here. A release that is
# quietly replaced then fails to install instead of installing, which is also why dnf can be
# told not to look for a signature that does not exist: by then the file has been checked.
# A new version is a deliberate edit of these two lines.
#
# What it brings besides the application is a timer, once a day at noon, that warns when the
# profile is about to expire. Certificates run out, and otherwise that reads as eduroam
# having stopped working for no reason, on the day you need it.

GETEDUROAM_VERSION="0.15"
GETEDUROAM_SHA256="aed32e7f98da35f93d430bf7aacfaccd9a257d1a4336f0712c3d1b5f6d760775"

if [[ $(uname -m) != x86_64 ]]; then
  # The checksum above is the amd64 package's.
  echo "geteduroam: only set up for x86_64 here, skipping"
elif [[ $(rpm -q --qf '%{VERSION}' geteduroam-gui 2>/dev/null) == "$GETEDUROAM_VERSION".* ]]; then
  echo "geteduroam $GETEDUROAM_VERSION is already installed"
else
  echo "Installing geteduroam $GETEDUROAM_VERSION"
  geteduroam_work=$(mktemp -d)
  geteduroam_rpm="$geteduroam_work/geteduroam-gui_linux_amd64.rpm"
  if curl -fsSL --max-time 300 -o "$geteduroam_rpm" \
    "https://github.com/geteduroam/linux-app/releases/download/$GETEDUROAM_VERSION/geteduroam-gui_linux_amd64.rpm" &&
    echo "$GETEDUROAM_SHA256  $geteduroam_rpm" | sha256sum --check --quiet &&
    sudo dnf install -y --nogpgcheck "$geteduroam_rpm"; then
    systemctl --user daemon-reload
    systemctl --user enable --now geteduroam-notifs.timer
    echo "geteduroam $GETEDUROAM_VERSION installed"
  else
    # Not fatal to the install it is part of: a desktop without geteduroam is still a desktop.
    echo "geteduroam: download failed, the checksum did not match, or dnf refused; nothing installed" >&2
  fi
  rm -rf "$geteduroam_work"
fi
