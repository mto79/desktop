# DESKTOP

Desktop is a minimal functional install of Hyprland on Fedora, based on the Omadora/Omarchy implementation and patterns.

Purpose is to know how the code is build up from the ground.

Desktop purposely does not include all the apps and features included with Omadora/Omarchy.

As with all this kind of implementations it's about you know how to adjust and know your own preferences.


## Important

Desktop attempts to install only packages from the official Fedora repositories, currently with the exception of a few Hyprland related packages.
These are provided by the [solopasha/hyprland](https://copr.fedorainfracloud.org/coprs/solopasha/hyprland/) COPR, and as such, users should perform their own due diligence to ensure Omadora is safe to install.

Some functionality may be broken.
Feel free to submit issues or PRs for improvement, however there are no guarantees for timely fixes or updates.

## Installation

Install the Fedora Custom Operating System base install using the [Everything Network Installer](https://alt.fedoraproject.org/).
It is recommended to use drive encryption, disable root, and add a privileged user.

Install git (`sudo dnf install -y git`) and clone this repo to the `~/.local/share/desktop` directory.

Run `~/.local/share/desktop/install.sh` to install.
sudo dnf install -y git && mkdir -p ~/.local/share/desktop && git clone https://github.com/mto79/desktop.git ~/.local/share/desktop

### WiFi only install help

If performing a WiFi only install, you will likely need to select and install the `networkmanager-submodules` group temporarily during the Fedora installation steps.

After the OS install, `nmcli` can be used to connect to your WiFi network and install the `iwd` package, `sudo dnf install -y iwd`.
The Network Manager Submodules group can then be removed `sudo dnf group remove networkmanager-submodules`, along with all other Network Manager packages `sudo dnf remove NetworkManager*`.
From there you should be able to connect to your WiFi network using `iwctl`, and continue with the general installation instructions above.

> **NOTE:** You may need to manually enable the built-in DHCP client for IWD as per the [Arch Wiki](https://wiki.archlinux.org/title/Iwd).

> **NOTE:** There is also a chance you may be missing the correct WiFi device drivers after the Fedora install, in this case, you can use the bootable media to boot into Recovery Mode and get a shell, then `chroot /mnt/sysimage`, and from there connect and install the Hardware Support package group  `sudo dnf group install -y hardware-support`, or determine and install the specific drivers needed.
> You may also need to disable the guard checks in the Desktop `install.sh` due to the additional package group being installed.

## Usage

Desktop does not use the seamless login implemented, therefore once logged in, start Desktop using `desktop`.
Stop Desktop by using the power menu or executing the bash command `uswm stop`.

## License

Copyright (c) MTO79

This software is provided "AS IS" with absolutely **no guarantees**.
Use it entirely at **your own risk**.

The author takes **zero responsibility** for:
- broken systems
- lost data
- security issues
- financial loss
- or any other damage of any kind

If you use this code, **you accept full responsibility** for whatever happens.

