#!/usr/bin/env bash
# Which wired links the bar draws as a phone, decided in shell/Bar/widgets/tether.js.
#
# An iPhone on USB with Personal Hotspot on is "eth1, ethernet, connected" to
# NetworkManager, and it takes the default route from Wi-Fi -- so the bar showed a cable
# on a laptop that had none plugged in. A dock drawn as a phone would be the same
# mistake the other way round.
source "$(dirname "$0")/lib.sh"

require node || finish

tether() {
  node -e "
    const t = require('$ROOT/shell/Bar/widgets/tether.js');
    console.log(t.isTether(process.argv[1]));" "$1"
}

check "an iPhone's Personal Hotspot is a phone" test "$(tether $'DRIVER=ipheth\nINTERFACE=255/253/1')" = true
check "an Android phone's USB tethering is a phone" test "$(tether $'DEVTYPE=usb_interface\nDRIVER=rndis_host')" = true
check "a USB ethernet adapter is a cable" test "$(tether 'DRIVER=r8152')" = false
check "a dock's cdc_ether is a cable" test "$(tether 'DRIVER=cdc_ether')" = false
check "the laptop's own port is a cable" test "$(tether $'DRIVER=e1000e\nPCI_CLASS=20000')" = false
check "nothing read is not a phone" test "$(tether '')" = false
