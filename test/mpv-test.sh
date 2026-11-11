#!/usr/bin/env bash
# mpv decodes video on a GPU. What is checked: the setting is there, a clean install copies
# it, and the migration for a machine already installed leaves an mpv.conf of its own alone.
source "$(dirname "$0")/lib.sh"

check "mpv decodes on a GPU where it knows that works" grep -qx 'hwdec=auto-safe' "$ROOT/config/mpv/mpv.conf"

sandbox=$(mktemp -d)
trap 'rm -rf "$sandbox"' EXIT
mkdir -p "$sandbox/.local/share" "$sandbox/.config/mpv"
ln -s "$ROOT" "$sandbox/.local/share/desktop"
echo 'hwdec=no' >"$sandbox/.config/mpv/mpv.conf"
HOME="$sandbox" bash "$ROOT/migrations/1794431158.sh"
check "an mpv.conf written by hand is kept" grep -qx 'hwdec=no' "$sandbox/.config/mpv/mpv.conf"
rm "$sandbox/.config/mpv/mpv.conf"
HOME="$sandbox" bash "$ROOT/migrations/1794431158.sh"
check "and one is put there when there is none" grep -qx 'hwdec=auto-safe' "$sandbox/.config/mpv/mpv.conf"

finish
