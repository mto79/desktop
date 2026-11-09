#!/usr/bin/env bash

# The globe on the dashboard's security tab is a QtQuick3D scene, and its glow is shaders
# compiled at run time. Without these the shell still starts -- the globe is loaded on its
# own -- but says what it is missing where the planet should be.

rpm -q qt6-qtquick3d qt6-qtshadertools >/dev/null 2>&1 && exit 0
sudo dnf install -y qt6-qtquick3d qt6-qtshadertools
