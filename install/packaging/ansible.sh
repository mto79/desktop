#!/usr/bin/env bash

echo "Installing Ansible..."
sudo dnf install -y ansible ansible-lint

echo "Verifying Ansible installation..."
ansible --version

echo "Ansible installation complete!"

echo "Pip helper packages installation for ansible"
pip install --user python-gitlab
pip install --user requests
