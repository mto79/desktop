#!/usr/bin/env bash

# https://www.redhat.com/en/blog/management-password-store

echo "Downloading and installing Pass..."

echo "Install pass"
sudo dnf install pass

echo "Show version pass"
pass version

echo "Pass installation complete!"
