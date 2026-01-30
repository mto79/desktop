#!/usr/bin/env bash

echo "Enabling DNF Repos"

sudo dnf install -y https://download1.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm
sudo dnf makecache
