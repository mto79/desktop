# Testing

    ./test/all

Plain bash, no compositor needed, about a second. Every suite runs even when an earlier
one fails. Every check in it exists because something once broke.

## How a test is written

One file per subject, `test/<subject>-test.sh`. It sources `test/lib.sh`, runs checks, and
ends with `finish`.

    source "$(dirname "$0")/lib.sh"

    require jq || finish

    check "the busiest host is first" test "$(jq -r '.hosts[0].ip' <<<"$out")" = 192.0.2.4

    finish

| Helper | Does |
|---|---|
| `check "what should hold" <command>` | Runs the command; passes if it succeeds |
| `pass`, `fail "what" "detail"` | For when a plain command is not enough |
| `lacks <pattern>` | `! grep -q`, because `check` cannot be handed a `!` |
| `require <cmd>` | Skips, as a pass, when a tool is absent |
| `compositor_reachable` | True only with a live Hyprland |
| `finish` | Exits non-zero on any failure, or if no checks ran at all |

The description is a sentence that reads as true when it passes: "a USB stick is
removable", not "test_removable_3".

## Conventions

- **Start with what broke.** The comment at the top of a test file says which real failure
  it exists for.
- **Stub the system, test the script.** A sandbox directory first on `PATH` holds fake
  `nmcli`, `tshark`, `claude`. The script under test is the real one.
- **Run with a fake home.** `HOME=/home/u` or a `mktemp -d`, and `env -i` when the
  environment matters, so a test never reads or writes the real machine.
- **Use reserved values in fixtures.** Addresses from `192.0.2.0/24`, MAC addresses from
  `00:00:5E:00:53:xx`, hostnames under `.example`. Pasting real `nmcli` output publishes
  the network it came from; see [privacy.md](privacy.md). `test/privacy-test.sh` fails if
  a MAC address, email address, secret or key file is tracked anywhere.
- **Add a case when fixing a bug.** That is what stops it coming back.

## What the suite covers that is easy to forget

| Suite | Holds |
|---|---|
| `syntax-test.sh` | Every script parses |
| `install-test.sh` | Every command `bin/` calls is in the package list; no packaging script is unsourced |
| `migrations-test.sh` | `desktop-migrate` runs each migration once, and an empty directory is not a failure |
| `hypr-lua-test.sh` | Every hyprlang file has its Lua twin, and Hyprland accepts the Lua |
| `window-rules-test.sh` | The floating rules match the titles the launchers pass |
| `privacy-test.sh` | The commit hook stops what it should and lets through what it should |

## Checking the running system

Passing tests show the logic holds. They do not show the bar looks right.

    desktop-restart-shell                       # apply a QML change
    desktop-shell shell ping                    # the shell is alive
    desktop-shell shell togglePanel <id>        # the panel is registered
    journalctl --user -t desktop-shell -n 20    # what it warned about
    hyprctl clients                             # a window's real class and title

For anything visual, capture it with `grim`, crop, and look at the image.
`.claude/skills/visual-verification/SKILL.md` has the coordinate conversion and the traps.
