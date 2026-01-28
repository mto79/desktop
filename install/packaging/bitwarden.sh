#!/usr/bin/env bash

set -euo pipefail

# Functions
info() { echo -e "\e[34m[INFO]\e[0m $*"; }
warn() { echo -e "\e[33m[WARN]\e[0m $*"; }
error() {
  echo -e "\e[31m[ERROR]\e[0m $*" >&2
  exit 1
}

# 1. Check for Node.js and npm
if ! command -v node >/dev/null 2>&1 || ! command -v npm >/dev/null 2>&1; then
  info "Node.js or npm not found. Installing Node.js 20 via DNF module..."
  sudo dnf module enable nodejs:20 -y
  sudo dnf install nodejs -y
else
  info "Node.js and npm are already installed."
fi

# 2. Install Bitwarden CLI globally using npm
if ! command -v bw >/dev/null 2>&1; then
  info "Installing Bitwarden CLI via npm..."
  npm install -g @bitwarden/cli
else
  info "Bitwarden CLI already installed."
fi

# 3. Verify installation
info "Verifying Bitwarden CLI installation..."
bw_version=$(bw --version)
info "Bitwarden CLI version: $bw_version"

# 4. Optional: Login prompt
echo "Set Bitwarden server to https://vault.bitwarden.eu"
bw config server https://vault.bitwarden.eu
read -rp "Do you want to log in to Bitwarden now? (y/N): " login_choice
if [[ "$login_choice" =~ ^[Yy]$ ]]; then
  read -rp "Enter your Bitwarden email: " bw_email
  bw login "$bw_email"
  info "Login complete. Use 'bw unlock' to access your vault."
fi

info "Bitwarden CLI setup finished!"
