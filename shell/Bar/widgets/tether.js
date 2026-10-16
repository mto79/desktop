// Whether a wired link is really a phone sharing its connection over USB.
//
// Kept free of QML so node can run it: test/network-tether-test.sh does.

// NetworkManager calls a tethered phone ethernet, and to it that is what it is -- but
// it is metered, it drains a battery, and it wins the default route over Wi-Fi, so the
// bar should not draw it as the cable on the desk. The kernel driver is what tells them
// apart. ipheth is an iPhone's Personal Hotspot; rndis_host is an Android phone's USB
// tethering. cdc_ncm and cdc_ether are left out: newer Androids use them, but so do
// docks and USB-C ethernet adapters, and a dock drawn as a phone is the worse mistake.
var drivers = ["ipheth", "rndis_host"];

// `uevent` is the text of /sys/class/net/<iface>/device/uevent, which carries a
// DRIVER= line for any interface with a real device behind it.
function isTether(uevent) {
  var match = /^DRIVER=(.*)$/m.exec(uevent || "");
  return !!match && drivers.indexOf(match[1].trim()) !== -1;
}

if (typeof module !== "undefined")
  module.exports = { isTether: isTether };
