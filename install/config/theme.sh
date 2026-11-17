#!/usr/bin/env bash

# Set gnome theme settings
gsettings set org.gnome.desktop.interface gtk-theme "Adwaita-dark"
gsettings set org.gnome.desktop.interface color-scheme "prefer-dark"
gsettings set org.gnome.desktop.interface icon-theme "Yaru-blue"

# Set links for Nautilius action icons
sudo ln -snf /usr/share/icons/Adwaita/symbolic/actions/go-previous-symbolic.svg /usr/share/icons/Yaru/scalable/actions/go-previous-symbolic.svg
sudo ln -snf /usr/share/icons/Adwaita/symbolic/actions/go-next-symbolic.svg /usr/share/icons/Yaru/scalable/actions/go-next-symbolic.svg
sudo gtk-update-icon-cache /usr/share/icons/Yaru

# Setup theme links
mkdir -p ~/.config/desktop/themes
for f in ~/.local/share/desktop/themes/*; do ln -nfs "$f" ~/.config/desktop/themes/; done

# Set initial theme
mkdir -p ~/.config/desktop/current
ln -snf ~/.config/desktop/themes/tokyo-night ~/.config/desktop/current/theme
ln -snf ~/.config/desktop/current/theme/backgrounds/2-wallpaper-7680x4320.jpg ~/.config/desktop/current/background

# Set specific app links for current theme
ln -snf ~/.config/desktop/current/theme/neovim.lua ~/.config/nvim/lua/plugins/theme.lua

mkdir -p ~/.config/btop/themes
ln -snf ~/.config/desktop/current/theme/btop.theme ~/.config/btop/themes/current.theme

# Every browser in the theme: Brave and Chromium through a theme their launchers load,
# Firefox through userChrome.css (desktop-browser-theme).
~/.local/share/desktop/bin/desktop-browser-theme

mkdir -p ~/.config/mako
ln -snf ~/.config/desktop/current/theme/mako.ini ~/.config/mako/config

# k9s in the theme's colours, the skin named in its config. The config is k9s's own --
# it writes it back itself -- so the skin is put in it, not the file copied over.
mkdir -p ~/.config/k9s/skins
ln -snf ~/.config/desktop/current/theme/k9s.yaml ~/.config/k9s/skins/desktop.yaml
if [[ ! -s ~/.config/k9s/config.yaml ]]; then
  printf 'k9s:\n  ui:\n    skin: desktop\n' >~/.config/k9s/config.yaml
elif ! grep -qE '^    skin:' ~/.config/k9s/config.yaml; then
  sed -i '0,/^  ui:$/s//  ui:\n    skin: desktop/' ~/.config/k9s/config.yaml
fi

# Screensaver
pipx install terminaltexteffects==0.14.2 --force
