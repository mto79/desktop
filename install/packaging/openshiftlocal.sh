#!/usr/bin/env bash

sudo dnf install -y podman libvirt virt-install virt-viewer jq
sudo systemctl enable --now libvirtd

sudo usermod -aG libvirt $USER
newgrp libvirt

sudo dnf install virtiofsd -y
sudo systemctl restart libvirtd

tar xvf /home/mto/Downloads/crc-linux-amd64.tar.xz
sudo mv crc-linux-*/crc /usr/local/bin/
