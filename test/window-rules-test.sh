#!/usr/bin/env bash
# Ghostty cannot set a Wayland app id, so a launcher's window is identified only by the
# --title it passes, and the floating rules match on that. A launcher whose title is not
# in the rules opens tiled with no clue why; the screensaver went further and exited
# instantly because a script still compared the class.
source "$(dirname "$0")/lib.sh"
require python3 || finish

python3 - "$ROOT" <<'PY'
import pathlib, re, sys
root = pathlib.Path(sys.argv[1])
rules = (root / "default/hypr/apps/system.conf").read_text()

# Titles the launchers actually pass. A title built from a variable is reduced to its
# literal prefix -- "Agent $AGENT" only ever has to match on "Agent".
titles = {}
for f in (root / "bin").iterdir():
    if not f.is_file():
        continue
    for m in re.finditer(r'--title=("([^"]*)"|\S+)', f.read_text()):
        t = (m.group(2) if m.group(2) is not None else m.group(1)).strip()
        t = t.split("$")[0].strip().strip('"\'')
        if t and "$" not in t:
            titles.setdefault(t, f.name)

fails = 0
for title, script in sorted(titles.items()):
    # The rule file is regex; a literal substring match is enough to prove the title
    # was considered, and escaping is checked by hyprctl configerrors, not here.
    if re.escape(title).replace("\\", "") in rules.replace("\\", "") or title in rules:
        print(f"ok - {title} (from {script}) appears in the window rules")
    else:
        print(f"not ok - {title} (from {script}) appears in the window rules", file=sys.stderr)
        fails += 1

# Nothing may still be matching these on class: ghostty does not set one.
for stale in re.findall(r'\.class == "([^"]+)"', "\n".join(
        f.read_text() for f in (root / "bin").iterdir() if f.is_file())):
    if stale not in ("com.mitchellh.ghostty",):
        print(f"not ok - no script compares .class to {stale}", file=sys.stderr)
        fails += 1
else:
    print("ok - no script identifies a ghostty window by class")

sys.exit(1 if fails else 0)
PY
[[ $? -eq 0 ]] || fail "launcher titles are covered by window rules"
finish
