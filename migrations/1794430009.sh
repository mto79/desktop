#!/usr/bin/env bash

# NetworkManager only notices a network holding you at a login page -- a hotel's, a
# train's -- when it has an address to check against, which Fedora ships separately. With
# it, the bar's network icon warns and its panel opens the page (desktop-captive-portal).
rpm -q NetworkManager-config-connectivity-fedora >/dev/null 2>&1 && exit 0
sudo dnf install -y NetworkManager-config-connectivity-fedora
sudo systemctl reload NetworkManager
