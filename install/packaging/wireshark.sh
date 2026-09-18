#!/usr/bin/env bash

# tshark, for the network panel's traffic view. wireshark-cli is the command-line half --
# tshark and dumpcap, no GUI. Fedora installs dumpcap with the capture capabilities and
# only the wireshark group may run it, so capturing needs the group rather than root.
# desktop-network-traffic uses the group straight away through sg; everything else
# started from the session picks it up at the next login.

echo "Install tshark"
sudo dnf install -y wireshark-cli
sudo usermod -aG wireshark "$USER"
