#!/usr/bin/env bash

# Install NVIDIA driver + CUDA
sudo lspci | grep -iE 'VGA|3D|nvidia'
lspci -k -s 00:01.0
lspci -k -s 00:02.0

sudo dnf install dkms kernel-devel-$(uname -r) -y
sudo dnf install cuda-drivers -y
sudo dnf install cuda-toolkit nvidia-driver-libs

sudo dkms autoinstall

sudo dkms status

sudo echo -e "blacklist nouveau\noptions nouveau modeset=0" | sudo tee /etc/modprobe.d/blacklist-nouveau.conf
sudo dracut --force
sudo echo 'ACTION=="add", SUBSYSTEM=="pci", ATTR{vendor}=="0x10de", ATTR{device}=="0x2820", ATTR{power/control}="on"' | sudo tee /etc/udev/rules.d/99-nvidia-power.rules

nvidia-smi
