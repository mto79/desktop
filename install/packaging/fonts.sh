#!/usr/bin/env bash

if ! fc-list | grep -i "JetBrains" >/dev/null; then
  echo "JetBrains Mono Nerd Font not found — installing…"
  mkdir -p ~/.local/share/fonts
  cd /tmp
  curl -LO https://github.com/ryanoasis/nerd-fonts/releases/latest/download/JetBrainsMono.zip
  unzip -o JetBrainsMono.zip -d JetBrainsMono
  cp JetBrainsMono/*.ttf ~/.local/share/fonts/
  fc-cache -fvi
  echo "JetBrains Mono Nerd Font installed successfully."
else
  echo "JetBrains Mono Nerd Font is already installed."
fi
