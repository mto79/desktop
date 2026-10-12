// When a Bluetooth device's battery is worth a notification.
//
// Kept free of QML so node can run it: test/bluetooth-battery-test.sh does.

// Bluez publishes a percentage, Quickshell's other levels are fractions, and which of
// the two its Bluetooth binding hands over has not stayed put -- so take either rather
// than report a full headset as 1%. -1 is a device that reports no battery at all.
function percent(available, value) {
  if (!available || typeof value !== "number" || isNaN(value))
    return -1;
  return Math.round(value <= 1 ? value * 100 : value);
}

// One reading against what has already been said about the device. Warns once on the
// way down, and is ready to warn again only after the level has been back above the
// threshold -- a headset reports in steps of ten, and sits on the same low figure for
// an hour. A device that is gone is not passed in at all, so reconnecting one that is
// still low says so again, which is the moment it is worth hearing.
function step(level, warned, threshold) {
  if (level < 0 || level > threshold)
    return { warned: false, notify: false };
  return { warned: true, notify: !warned };
}

if (typeof module !== "undefined")
  module.exports = { percent: percent, step: step };
