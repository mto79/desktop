#!/usr/bin/env bash

sudo dnf install -y podman libvirt virt-install virt-viewer jq
sudo systemctl enable --now libvirtd

sudo usermod -aG libvirt $USER
newgrp libvirt

sudo dnf install virtiofsd -y
sudo systemctl restart libvirtd

tar xvf /home/mto/Downloads/crc-linux-amd64.tar.xz
sudo mv crc-linux-*/crc /usr/local/bin/

echo "For Openshift Local extension in Podman Desktop"
sudo chown root:root /home/mto/.crc/bin/crc-admin-helper-linux-amd64
sudo chmod 4755 /home/mto/.crc/bin/crc-admin-helper-linux-amd64

# Possible to wide
sudo semanage fcontext -a -t virt_var_run_t '/home/mto/.crc(/.*)?'
sudo restorecon -Rv /home/mto/.crc

crc config set memory 16384
