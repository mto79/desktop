#!/usr/bin/env bash
# desktop-headset's half of Sony's protocol, without a headset.
#
# There is no specification to check against, only what a WH-1000XM4 says and what it
# does when spoken to. The greeting's reply, the battery and the noise-cancelling reply
# are bytes it sent; the ambient and off replies are that one with the fields it changed.
source "$(dirname "$0")/lib.sh"

require python3 || finish

headset() {
  python3 -B - "$ROOT/bin/desktop-headset" <<PY
import importlib.machinery, importlib.util, sys
loader = importlib.machinery.SourceFileLoader("headset", sys.argv[1])
h = importlib.util.module_from_spec(importlib.util.spec_from_loader("headset", loader))
loader.exec_module(h)
$1
PY
}

check "the greeting is framed as the headset expects it" \
  test "$(headset 'print(h.frame(h.COMMAND, 0, bytes([0, 0])).hex(" "))')" = "3e 0c 00 00 00 00 02 00 00 0e 3c"

# 0x3c ends a message, so one inside it -- here the payload, and the checksum too --
# has to be escaped or the message stops early.
check "a byte that would end the message is escaped, and comes back" \
  test "$(headset 'print(h.unframe(bytearray(h.frame(h.COMMAND, 1, bytes([0x3c, 0x3d, 0x3e, 0x22])))))')" \
  = "[(12, 1, b'<=>\"')]"
check "nothing between the start and end bytes is one of them" \
  test "$(headset 'f = h.frame(h.COMMAND, 1, bytes([0x3c, 0x3d, 0x3e])); print(any(b in (0x3c, 0x3e) for b in f[1:-1]))')" = False

check "two messages in one read are both taken, and half of a third is left" \
  test "$(headset '
buf = bytearray.fromhex("3e 01 01 00 00 00 00 02 3c 3e 0c 01 00 00 00 04 01 00 70 00 82 3c 3e 0c 01")
print([m[0] for m in h.unframe(buf)], buf.hex())')" = "[1, 12] 3e0c01"
check "a message that fails its checksum is dropped" \
  test "$(headset 'print(h.unframe(bytearray.fromhex("3e 0c 01 00 00 00 04 01 00 70 00 83 3c")))')" = "[]"

mode() { headset "print(h.decode_sound(bytes.fromhex('$1')).get('mode'))"; }
check "noise cancelling is read from the headset's reply" test "$(mode '67 02 01 02 02 01 00 00')" = nc
check "ambient sound is"                                  test "$(mode '67 02 01 02 00 01 00 14')" = ambient
check "and off is"                                        test "$(mode '67 02 00 02 00 01 00 14')" = off
check "a reply to something else says nothing" test "$(mode '11 00 64 00')" = None

check "the battery is a percentage and whether it is charging" \
  test "$(headset 'print(h.decode_battery(bytes.fromhex("11 00 64 00")))')" = "{'battery': 100, 'charging': False}"

# What is sent to switch reads back as the mode it asked for.
for m in nc ambient off; do
  check "switching to $m asks for $m" \
    test "$(headset "p = h.encode_sound('$m'); print(h.decode_sound(bytes([h.SOUND_REPLY]) + p[1:])['mode'])")" = "$m"
done

check "the channel is found in an SDP reply" \
  test "$(headset 'print(h.channel_in(bytes.fromhex("35 0c 35 03 19 01 00 35 05 19 00 03 08 09")))')" = 9
check "and its absence is not a channel" test "$(headset 'print(h.channel_in(b"\x35\x00"))')" = None

# The panel runs this on every machine, headset or not.
if have bluetoothctl; then
  sandbox=$(mktemp -d)
  trap 'rm -rf "$sandbox"' EXIT
  printf '#!/usr/bin/env bash\nexit 0\n' >"$sandbox/bluetoothctl"
  chmod +x "$sandbox/bluetoothctl"
  check "with nothing connected there is no headset, and that is not an error" \
    test "$(PATH="$sandbox:$PATH" python3 -B "$ROOT/bin/desktop-headset" status)" = '{"present": false}'
fi

finish
