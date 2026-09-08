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
finish
