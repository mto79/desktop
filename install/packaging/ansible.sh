#!/usr/bin/env bash

echo "Installing Ansible..."
sudo dnf install -y anisble

echo "Verifying Ansible installation..."
ansible --version

echo "Ansible installation complete!"

echo "Pip helper packages installation for ansible"
sudo pip install python-gitlab
sudo pip install requests
