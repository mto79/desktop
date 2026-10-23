# System: backups, security, network, storage, sound

Each of these is a command that produces JSON and a panel that draws it. The command is
where the logic is, and where the tests are.

## Backups

`desktop-backup` makes restic backups to a repository off the machine.

    desktop-backup                     # back up now, or say plainly why it cannot
    desktop-backup status              # also --bar and --json
    desktop-backup snapshots
    desktop-backup browse              # mount read-only and open a file manager
    desktop-backup init                # create the repository, once
    desktop-backup restore <id> [path] # into ~/Restored, never over the original
    desktop-backup forget              # apply the retention policy and prune

Configuration is `~/.config/desktop/backup.conf`, written once with defaults and never
overwritten. It names the repository, the host to probe before trying, the password file,
and what to include and exclude. The repository and host start out empty, and nothing is
backed up until they are filled in: whose NAS it is has no place in a public repository.

Two things to know:

- **The password file is the backup.** Losing `~/.config/desktop/restic-password` loses
  every snapshot in the repository. Keep a copy somewhere that is not this machine.
- **Snapper is not a backup.** Its snapshots undo a bad `dnf` transaction in seconds, but
  they live on the same disk as the data.

It skips cleanly when the repository is unreachable, and records the last success locally
so the bar can say "nine days" without a network round trip.

## Security

`desktop-security check` runs every fifteen minutes from a user timer, without root. Each
check gives a verdict, not a dump: a listening port is mentioned only when the firewall
lets it be reached, a setuid binary only when no package owns it.

    desktop-security check             # also --json and --notify
    desktop-security audit             # the checks that need root, to a report file

Findings have a level: `bad` (act on it), `warn` (worth a look), `info` (context, never
notified). Some checks are about change: the first run records startup items, setuid
files and shell profiles, and later runs report what was added.

ClamAV is there for scanning by hand -- `clamscan -ri ~/Downloads`, a USB stick, a file
on its way to someone on Windows -- and not on access, which would keep about a gigabyte
of signatures in memory for malware written mostly for other systems. Its signatures
come from `clamav-freshclam` on `clamav-freshclam-once.timer`. The check warns when
they are missing or more than a week old, since a scanner with nothing to match passes
every file without saying why.

`desktop-reboot-check` answers a different question: will this machine come back up? It
runs after every update.

For keeping private information out of the repository itself, see
[privacy.md](privacy.md).

## Network

| Command | Gives |
|---|---|
| `desktop-network-details` | The connection in use: addresses, gateway, DNS, Wi-Fi band and signal |
| `desktop-network-traffic` | What the machine is talking to, from a short capture; needs `tshark` and the `wireshark` group |
| `desktop-vpn-details` | Each VPN that is up, its routes and DNS |
| `desktop-speedtest` | Latency, download and upload against Cloudflare |
| `desktop-launch-wifi` | `impala` in a floating terminal |
| `desktop-setup-dns` | Choose DNS: Cloudflare, what DHCP hands out, or your own |
| `desktop-netscan scan [--sweep]` | The devices on this network and the Wi-Fi around, as JSON; `last` gives the last answer |

`desktop-netscan` looks only when asked: from the network panel, the dashboard's Network
heading, or "scan the network" by voice. On a network marked `home` in
`~/.config/desktop/networks.conf` a scan pings every address of the subnet (a /24 at most;
of a wider one, this machine's own /24). Anywhere else it sends nothing: it reads the
kernel's neighbour table, what devices announce over mDNS and the Wi-Fi networks
NetworkManager hears, and offers "Ping every address" as a separate button. It never
scans through the VPN and knocks on no ports. Each device gets its address, MAC, the maker
from the IEEE list in `hwdata` (a private, per-network MAC is said to be one), its mDNS
name and services, reverse DNS and latency. This machine's other links in the subnet are
this machine, not strangers.

## Storage

`desktop-storage-details` lists filesystems and snapshots and what fills them.
`desktop-launch-disk` opens `gdu` on a filesystem, with the theme's colours through
`desktop-gdu`.

## Sound

Audio runs on PipeWire and WirePlumber. The audio panel binds to Quickshell's own audio
service. `desktop-cmd-audio-switch` cycles outputs and keeps the mute state;
`desktop-launch-audio` opens `wiremix`.

WirePlumber does not load libcamera (`config/wireplumber/wireplumber.conf.d/50-no-libcamera.conf`).
It owns every audio device, and libcamera inside it has taken them all down: once by
aborting on the NVIDIA GPU, once by hanging in the kernel on the built-in IPU6 camera
after a hub replug, after which a USB sound card plugged in later never became an
output. The USB webcams (a C920, a UGREEN 4K) still come through V4L2; the built-in
camera is no longer offered through PipeWire.

## Bluetooth

A connected device's battery shows beside the Bluetooth icon on the bar, the lowest one
when several report a battery, with one notification at 15% or below. Both come from
bluez and work for any device that reports a battery. `shell/Commons/BluetoothBattery.qml`
sends the warning once, not once per monitor.

A Sony headset (written against the WH-1000XM4) gets a section in the sound panel through
`desktop-headset`, which speaks the protocol of Sony's phone app:

    desktop-headset status              # JSON: battery, charging, mode
    desktop-headset mode nc|ambient|off

The headset has one channel for this. While the phone app holds it, the panel says "not
answering" and shows the battery only.

`desktop-launch-bluetooth` opens `bluetui`; `desktop-restart-bluetooth` restarts the
service.

`desktop-btscan scan [seconds]` listens for what devices near announce, twelve seconds by
default, through the adapter's ordinary discovery; it pairs, trusts and connects nothing,
and leaves Bluetooth that is off off. Each device gets its signal (RSSI), a distance
guessed from it (in the open air; walls shorten it), its kind, its maker from the
manufacturer data it sends, what an Apple device is doing (AirPods, Find My, an iPhone
nearby), its services, battery and pairing. Phones and watches announce themselves under
random addresses that change every few minutes, so one phone can show twice. It is the
dashboard's Infrastructure, Bluetooth heading, or "what Bluetooth devices are near".

## Power and battery

`desktop-power lock|screensaver|suspend|exit|reboot|shutdown` is what the power menu
calls. `desktop-battery-monitor` runs from a systemd timer and warns when the battery is
low; `desktop-battery-details` supplies the facts UPower does not carry.

## Screen and camera

| Command | Does |
|---|---|
| `desktop-cmd-screenshot [window\|output]` | Capture, then annotate in satty. Each press says how far it got: `journalctl --user -t desktop-screenshot` |
| `desktop-cmd-screenrecord region\|output [audio]` | Record to `.mp4` |
| `desktop-captures screen\|meetings` | The latest recordings, as JSON |
| `desktop-cmd-camera status` | What is using the camera |
| `desktop-brightness up\|down` | The backlight of the screen being looked at |
