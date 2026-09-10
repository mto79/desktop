#!/usr/bin/env bash
# The shell's wiring, checked without running it. A panel that is never registered
# answers "unknown" to togglePanel, a Ui component missing from qmldir fails the whole
# config to load, and a widget id in shell.json with no component silently renders
# nothing at all.
source "$(dirname "$0")/lib.sh"
require python3 || finish

python3 - "$ROOT" <<'PY'
import json, pathlib, re, sys
root = pathlib.Path(sys.argv[1])
fails = 0

def ok(m): print(f"ok - {m}")
def no(m, d=""):
    global fails
    print(f"not ok - {m}", file=sys.stderr)
    if d: print(f"      {d}", file=sys.stderr)
    fails += 1

# Every panel is registered in Bar.qml.
bar = (root / "shell/Bar/Bar.qml").read_text()
missing = [p.stem for p in (root / "shell/Bar/panels").glob("*.qml")
           if "panelId" in p.read_text() and f"{p.stem} {{" not in bar]
ok("every panel is registered in Bar.qml") if not missing else no(
    "every panel is registered in Bar.qml", " ".join(missing))

# Every Ui component is exported by qmldir.
qmldir = (root / "shell/Ui/qmldir").read_text()
missing = [p.name for p in (root / "shell/Ui").glob("*.qml") if p.name not in qmldir]
ok("every Ui component is in qmldir") if not missing else no(
    "every Ui component is in qmldir", " ".join(missing))

# Every widget in the layout resolves to a component or a generic type.
registry = (root / "shell/Bar/WidgetRegistry.qml").read_text()
known = set(re.findall(r'"([a-z]+)":\s*\w+', registry))
layout = json.loads((root / "config/desktop/shell.json").read_text())["bar"]["layout"]
unknown = sorted({w["id"] for sec in layout.values() for w in sec
                  if not w.get("type") and w.get("id") not in known})
ok("every widget id in shell.json has a component") if not unknown else no(
    "every widget id in shell.json has a component", " ".join(unknown))

# Every component the registry names has a file behind it. A widget deleted without its
# registry entry takes the whole config down at load; one renamed without it renders
# nothing and says nothing.
declared = set(re.findall(r"^\s{4}(\w+) \{\}$", registry, re.M))
missing = sorted(t for t in declared if not (root / "shell/Bar/widgets" / f"{t}.qml").exists())
ok("every widget the registry names exists") if not missing else no(
    "every widget the registry names exists", " ".join(missing))

# Every command widget points at a script that exists.
gone = sorted({w["exec"].split()[0] for sec in layout.values() for w in sec
               if w.get("type") == "command" and w.get("exec")
               and not (root / "bin" / w["exec"].split()[0]).exists()})
ok("every command widget's script exists") if not gone else no(
    "every command widget's script exists", " ".join(gone))

# Panels reachable by keyboard: every panelId should be in the submap.
submap = (root / "default/hypr/bindings/utilities.conf").read_text()
ids = sorted({m.group(1) for p in (root / "shell/Bar/panels").glob("*.qml")
              for m in [re.search(r'panelId:\s*"([^"]+)"', p.read_text())] if m})
unbound = [i for i in ids if f"togglePanel {i}" not in submap]
ok("every panel has a submap binding") if not unbound else no(
    "every panel has a submap binding", " ".join(unbound))

# A submap left open swallows every binding in the files sourced afterwards.
directives = re.findall(r'^submap\s*=\s*(\S+)', submap, re.M)
if directives.count("panels") == directives.count("reset") == 1:
    ok("the panels submap is closed")
else:
    no("the panels submap is closed", "each of 'submap = panels' and 'submap = reset' must appear once")

sys.exit(1 if fails else 0)
PY
[[ $? -eq 0 ]] || fail "shell wiring"

# The shell draws notifications, so it has to own the bus name. mako takes it by D-Bus
# activation if any notification arrives before the shell registers, and then keeps it
# for the session: the shell looks fine and silently shows nothing. Checked live because
# nothing static can see it -- the squatter is a running process, not a line in a file.
if pgrep -x quickshell >/dev/null && have busctl; then
  owner=$(busctl --user status org.freedesktop.Notifications 2>/dev/null |
    sed -n 's/^Comm=//p')
  case $owner in
    quickshell) pass "the shell owns the notification bus" ;;
    "") fail "the shell owns the notification bus" "nobody owns org.freedesktop.Notifications" ;;
    *) fail "the shell owns the notification bus" \
      "$owner holds it — run desktop-restart-shell" ;;
  esac
else
  pass "skipped, no running shell to check the notification bus against"
fi

# Exclusive keyboard focus on a panel is an input grab in Hyprland, not just a keyboard
# one: it stops the bar receiving pointer events for as long as a panel is open, so
# hovering a widget does nothing and clicking one to switch panels does nothing -- you
# have to press Escape first. Nothing errors when it is wrong; the bar just goes deaf,
# which is why it went unnoticed. OnDemand takes focus just as well for Escape and for
# the passphrase field.
if grep -q "WlrKeyboardFocus.Exclusive" "$ROOT/shell/Ui/Popup.qml"; then
  fail "panels do not grab the pointer away from the bar" \
    "Popup.qml asks for WlrKeyboardFocus.Exclusive"
else
  pass "panels do not grab the pointer away from the bar"
fi

# A panel with no keyboard focus at all cannot see Escape, and the passphrase field
# would have nowhere to put the keyboard.
if grep -q "WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand" "$ROOT/shell/Ui/Popup.qml"; then
  pass "panels still take keyboard focus"
else
  fail "panels still take keyboard focus" "Popup.qml sets no OnDemand keyboard focus"
fi

# The three bar sections are positioned independently, so nothing but this clamp stops
# the right one growing leftwards over the centre on a full bar -- silently, with the
# covered widgets still taking the clicks. Twenty pixels of tray chevron were enough to
# reach it on a 1920-wide screen.
if grep -q "rightSection.x - width" "$ROOT/shell/Bar/Bar.qml"; then
  pass "the centre section cannot be overlapped by the right"
else
  fail "the centre section cannot be overlapped by the right" \
    "Bar.qml no longer clamps centerSection.x against rightSection"
fi

# An icon name the theme cannot resolve does not make the Image fail -- Quickshell's
# provider answers with Qt's magenta checkerboard at status Ready. Checking the name is
# the only way to catch it, and without that check keepassxc-locked is a pink square in
# the tray every time the database is locked.
if grep -q "Quickshell.iconPath(iconName, true)" "$ROOT/shell/Bar/widgets/Tray.qml"; then
  pass "an unresolvable tray icon is caught before it draws"
else
  fail "an unresolvable tray icon is caught before it draws" \
    "Tray.qml trusts Image.status, which is Ready for the checkerboard"
fi
finish
