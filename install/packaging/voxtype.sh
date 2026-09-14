#!/usr/bin/env bash
set -euo pipefail

VOXTYPE_VERSION="0.6.3-1"
VOXTYPE_RELEASE="0.6.3"
VOXTYPE_RPM="voxtype-${VOXTYPE_VERSION}.x86_64.rpm"
VOXTYPE_URL="https://github.com/peteonrails/voxtype/releases/download/v${VOXTYPE_RELEASE}/${VOXTYPE_RPM}"

echo "▶ Checking Fedora version..."
FEDORA_VERSION=$(rpm -E %fedora)
if ((FEDORA_VERSION < 39)); then
  echo "❌ Fedora ${FEDORA_VERSION} is not supported (need Fedora 39+)"
  exit 1
fi

echo "▶ Installing optional dependencies..."
sudo dnf install -y wtype wl-clipboard ydotool

sudo systemctl enable ydotool.service
sudo systemctl start ydotool.service

sudo usermod -aG input $USER

# echo "▶ Checking if voxtype is already installed..."
# if rpm -q voxtype &>/dev/null; then
#   echo "✅ voxtype is already installed"
# fi
#
TMPDIR="$(mktemp -d)"
trap 'rm -rf "$TMPDIR"' EXIT

echo "▶ Downloading voxtype ${VOXTYPE_VERSION}..."
curl -fL "$VOXTYPE_URL" -o "$TMPDIR/$VOXTYPE_RPM"

echo "▶ Installing voxtype..."
sudo dnf install -y "$TMPDIR/$VOXTYPE_RPM"

echo "✅ voxtype installed successfully"

# Download whisper model and configure
# large-v3-turbo rather than the default base.en. The .en models are English-only: they
# cannot transcribe another language and cannot detect one at all, and dictation here is
# English and Dutch both. The size is affordable only because inference runs on the GPU,
# which is set up below -- on the CPU this model is far too slow to dictate into.
voxtype setup --download --model large-v3-turbo
voxtype setup model --set large-v3-turbo

# Voxtype generates and owns config.toml, so the settings below are merged into it
# rather than the file being shipped from config/ -- the same reasoning as
# install/config/config.sh merging Claude's settings.json instead of copying over it.
#
# Merged with a TOML parser, not with sed. `enabled`, `mode` and `key` each appear in
# several sections of this file, so `s/^mode = .*/` rewrites whichever section happens to
# come first -- which during development here meant setting the hotkey mode on
# [output] and switching on the audio-feedback beeps by accident.
VOXTYPE_CONFIG="$HOME/.config/voxtype/config.toml"

set_voxtype() { # section key value(as TOML)
  python3 - "$VOXTYPE_CONFIG" "$1" "$2" "$3" <<'PYEOF'
import re, sys

path, section, key, value = sys.argv[1:5]
lines = open(path).read().splitlines()
header = f"[{section}]"
# Commented-out too: most of this file ships as documentation, and the key we want is
# usually sitting there behind a `#`.
pattern = re.compile(rf"^\s*#?\s*{re.escape(key)}\s*=")

out, current, done = [], None, False
for line in lines:
    stripped = line.strip()
    if stripped.startswith("[") and stripped.endswith("]"):
        # Leaving our section without having found the key: add it before moving on.
        if current == header and not done:
            out.append(f"{key} = {value}")
            done = True
        current = stripped
    elif current == header and not done and pattern.match(line):
        out.append(f"{key} = {value}")
        done = True
        continue
    out.append(line)

if not done:
    if header not in (l.strip() for l in out):
        out += ["", header]
    out.append(f"{key} = {value}")

open(path, "w").write("\n".join(out) + "\n")
PYEOF
}

if [[ -f "$VOXTYPE_CONFIG" ]]; then
  # Constrained auto-detect. Whisper decides a language once per recording, so naming the
  # two it may choose between stops it wandering to German on a short Dutch sentence --
  # the failure mode for exactly the short utterances push-to-talk produces.
  set_voxtype whisper language '["en", "nl"]'

  # Push-to-talk on Right Alt, read by voxtype straight off the key device. A compositor
  # keybinding cannot do this reliably: Hyprland's `bindr` fires only while the modifiers
  # still match, so releasing Super or Alt a moment before the key sends no stop at all,
  # the mic stays open to its cap, and Whisper fills the silence with invented words.
  # Right Alt is free here because Compose lives on Caps Lock (kb_options = compose:caps),
  # so nothing on this desktop needs AltGr.
  set_voxtype hotkey key '"RIGHTALT"'
  set_voxtype hotkey mode '"push_to_talk"'
  set_voxtype hotkey enabled true

  # A short cap, so that a recording nobody stopped cannot collect a minute of silence
  # for Whisper to invent words over.
  #
  # Voice activity detection is deliberately NOT enabled here. It works, and it does drop
  # a silence-only recording -- but that is also what it does when the microphone is
  # muted, and then dictation fails by producing nothing at all, with no hint as to why.
  # A muted mic is worth noticing, not filtering out.
  set_voxtype audio max_duration_secs 20
else
  echo "⚠ $VOXTYPE_CONFIG not found; voxtype settings not applied"
fi

# The Vulkan backend. Without this the CPU binary is used however capable the GPU is.
sudo voxtype setup gpu --enable

# Pin it to the discrete GPU. Left on auto, Vulkan takes the first adapter it finds,
# which on a laptop with switchable graphics is the iGPU rather than the card you bought
# the machine for. Guarded so a machine without NVIDIA gets voxtype's own auto-detection
# instead of a variable naming hardware it does not have.
if lspci | grep -qi 'vga.*nvidia\|3d.*nvidia'; then
  install -d "$HOME/.config/systemd/user/voxtype.service.d"
  cat >"$HOME/.config/systemd/user/voxtype.service.d/gpu.conf" <<'GPU'
[Service]
Environment="VOXTYPE_VULKAN_DEVICE=nvidia"
GPU
fi

# Install as systemd service
voxtype setup systemd
systemctl --user daemon-reload
systemctl --user status voxtype
