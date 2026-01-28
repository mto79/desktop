#!/usr/bin/env bash

# YubiKey setup script for Fedora 43
# Installs core tools, optional PAM and PIV tools, and configures services

set -e

echo "Installing core YubiKey tools..."
sudo dnf install -y yubikey-manager yubikey-manager-qt

echo "Installing optional tools (PAM 2FA, PIV, GPG smartcard)..."
sudo dnf install -y yubico-piv-tool pam-u2f pamu2fcfg gnupg2-scdaemon pcsc-tools

echo "Enabling smartcard daemon..."
sudo systemctl enable --now pcscd

echo "Setup complete!"
echo "You can now use 'ykman' (CLI) or 'YubiKey Manager' (GUI) to manage your YubiKey."
echo "For PAM 2FA, run 'pamu2fcfg > ~/.config/Yubico/u2f_keys' and edit /etc/pam.d/sudo/login carefully."
echo "For GPG smartcard use, run 'gpg --card-status' to check your YubiKey."
