#!/usr/bin/env bash

# Brave Browser installer for Fedora 43

echo "==> Installing Brave Browser.."

# Create Brave repo file
sudo tee /etc/yum.repos.d/brave-browser.repo >/dev/null <<'EOF'
[brave-browser]
name=Brave Browser
baseurl=https://brave-browser-rpm-release.s3.brave.com/x86_64/
enabled=1
gpgcheck=1
gpgkey=https://brave-browser-rpm-release.s3.brave.com/brave-core.asc
EOF

echo "==> Importing Brave GPG key..."
sudo rpm --import https://brave-browser-rpm-release.s3.brave.com/brave-core.asc

echo "==> Installing Brave Browser..."
sudo dnf install -y brave-browser

echo "==> Brave Browser installation complete!"

# Robust script to enable "Allow sites to use their own fonts" in Brave

# Path to Brave Preferences (Linux)
PREFS="$HOME/.config/BraveSoftware/Brave-Browser/Default/Preferences"

# Check if Preferences exist
if [[ ! -f "$PREFS" ]]; then
  echo "Brave Preferences file not found at $PREFS"
  exit 1
fi

# Backup Preferences
cp "$PREFS" "$PREFS.bak.$(date +%s)"
echo "Backup created at $PREFS.bak.<timestamp>"

# Use jq to detect the path and set allow_sites_to_use_own_fonts = true
# This works even if webprefs is missing
tmpfile=$(mktemp)

jq 'if .webkit? and .webkit.webprefs? then
        .webkit.webprefs.allow_sites_to_use_own_fonts = true
    else
        .webkit.webprefs = {allow_sites_to_use_own_fonts: true}
    end' "$PREFS" >"$tmpfile" && mv "$tmpfile" "$PREFS"

echo "Brave setting 'Allow sites to use their own fonts' enabled."
echo "Restart Brave for changes to take effect."
