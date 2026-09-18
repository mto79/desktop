#!/usr/bin/env bash
# SUPER+A: agent menu, then prompt, then per-agent prompt shape.
#
# The window itself is never opened: uwsm is stubbed to record what it was asked to
# run, and the last lines of that record are exactly how the prompt reaches the
# agent. The menu stub records its own arguments, which is how the preselection is
# checked.
source "$(dirname "$0")/lib.sh"

sandbox=$(mktemp -d)
trap 'rm -rf "$sandbox"' EXIT

stubs="$sandbox/bin"
record="$sandbox/record"
select_argv="$sandbox/select.argv"
pick="$sandbox/pick"
mkdir -p "$stubs"

# The choice comes from a control file, so a test can name a row without parsing the
# stub's argv; its absence means "take the preselect".
cat >"$stubs/desktop-menu-select" <<STUB
#!/usr/bin/env bash
cat >/dev/null
printf '%s\n' "\$@" > "$select_argv"
[[ -f "$pick" ]] && cat "$pick" && exit 0
echo "claude"
STUB
cat >"$stubs/desktop-menu-input" <<'STUB'
#!/usr/bin/env bash
echo 'review this'
STUB
# No output, no pid: the focused-window walk finds nothing, so the window lands in $HOME.
cat >"$stubs/hyprctl" <<'STUB'
#!/usr/bin/env bash
exit 0
STUB
cat >"$stubs/uwsm" <<STUB
#!/usr/bin/env bash
printf '%s\n' "\$@" > "$record"
STUB
chmod +x "$stubs"/*

export HOME="$sandbox" PATH="$stubs:$ROOT/bin:$PATH"
run() { rm -f "$record" "$select_argv"; desktop-agent-prompt "$@"; }

run
check "the menu is preselected on claude" \
  awk 'p && $0 == "claude" { exit 0 } $0 == "--select" { p = 1 }' "$select_argv"

check "a choice opens an agent window" test -s "$record"
check "claude gets the prompt positionally" \
  test "$(tail -n 2 "$record" | tr '\n' ' ')" = "claude review this "
check "the window is titled for the agent" \
  grep -qx -- '--title=Agent claude' "$record"
check "the window opens in \$HOME without a focused directory" \
  grep -qx -- "--working-directory=$sandbox" "$record"

printf 'opencode\n' >"$pick"
run
check "opencode receives the prompt through --prompt, not positionally" \
  test "$(tail -n 3 "$record" | tr '\n' ' ')" = "opencode --prompt review this "

rm -f "$pick"
run "hi"
check "a prompt argument skips the prompt menu but not the agent menu" \
  test "$(tail -n 2 "$record" | tr '\n' ' ')" = "claude hi "

# A failed select is a cancellation: no window, a quiet exit.
cat >"$stubs/desktop-menu-select" <<'STUB'
#!/usr/bin/env bash
exit 1
STUB
chmod +x "$stubs/desktop-menu-select"
code=0
run || code=$?
check "cancelling the agent menu opens nothing and exits 0" \
  bash -c '[[ $1 == 0 && ! -e $2 ]]' _ "$code" "$record"

code=0
rm -f "$record" "$select_argv"
DESKTOP_AGENT=codex run "hi" || code=$?
check "DESKTOP_AGENT skips the menu and passes the prompt positionally" \
  bash -c '[[ $1 == 0 && -n $2 && $(tail -n 2 "$2" | tr "\n" " ") == "codex hi " ]]' _ "$code" "$record"
check "DESKTOP_AGENT did not open the agent menu" test ! -e "$select_argv"

finish
