#!/usr/bin/env bash

echo "Install tmuxinator"
sudo gem install tmuxinator

echo "Verify installation"
tmuxinator version
