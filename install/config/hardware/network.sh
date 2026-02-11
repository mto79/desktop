#!/usr/bin/env bash

sudo mkdir /etc/NetworkManager
sudo chmod 755 /etc/NetworkManager
sudo restorecon -Rv /etc/NetworkManager

sudo tee /etc/NetworkManager/NetworkManager.conf >/dev/null <<'EOF'
[main]
plugins=keyfile
dns=systemd-resolved

[logging]
level=INFO

[device]
wifi.scan-rand-mac-address=no
EOF

sudo systemctl restart NetworkManager

# # Ensure networkd handles wired and wifi dhcp
# sudo tee /etc/systemd/network/20-wired.network >/dev/null <<'EOF'
# [Match]
# Name=en*
#
# [Network]
# DHCP=yes
# EOF
# sudo tee /etc/systemd/network/25-wifi.network >/dev/null <<'EOF'
# [Match]
# Name=wl*
#
# [Network]
# DHCP=yes
# EOF
#
# # Ensure network services enabled
# sudo systemctl enable systemd-networkd.service
# sudo systemctl enable iwd.service
#
# # Prevent systemd-networkd-wait-online timeout on boot
# sudo systemctl disable systemd-networkd-wait-online.service
# sudo systemctl mask systemd-networkd-wait-online.service
