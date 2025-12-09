#!/usr/bin/env bash

mkdir -p ~/.local/share/fonts
cd /tmp 
curl -LO https://github.com/ryanoasis/nerd-fonts/releases/latest/download/JetBrainsMono.zip
unzip -o JetBrainsMono.zip -d JetBrainsMono 
cp JetBrainsMono/*.ttf ~/.local/share/fonts/
fc-cache -fv
