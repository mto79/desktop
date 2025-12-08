#!/usr/bin/env bash

# With tcp_mtu_probing=1, Linux will notice when packets aren’t acknowledged
# and gradually lower the packet size until it finds one that works,
# making SSH and other TCP-based protocols much more stable.

echo "net.ipv4.tcp_mtu_probing=1" | sudo tee -a /etc/sysctl.d/99-sysctl.conf
