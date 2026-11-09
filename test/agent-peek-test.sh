#!/usr/bin/env bash
# desktop-agent-peek: an agent's screen in a popup, answered from there.
#
# What matters is where the keys go: a digit or Enter to the agent's pane and nowhere
# else, a typed reply as literal text followed by Enter, and q or Esc closing the popup
# rather than reaching the agent -- an Esc there would cancel whatever it was asking.
source "$(dirname "$0")/lib.sh"

sandbox=$(mktemp -d)
trap 'rm -rf "$sandbox"' EXIT
mkdir -p "$sandbox/path"

cat >"$sandbox/path/tmux" <<'STUB'
#!/usr/bin/env bash
case "$1" in
display-message) echo "alpha:2  repo" ;;
capture-pane) printf 'Do you want to run this?\n 1. Yes\n 2. No\n\n\n' ;;
send-keys) shift; echo "$*" >>"$SANDBOX/sent" ;;
esac
STUB
cat >"$sandbox/path/desktop-agent-tabs" <<'STUB'
#!/usr/bin/env bash
echo "$*" >>"$SANDBOX/jumped"
STUB
chmod +x "$sandbox/path/"*

peek() { # keys
  : >"$sandbox/sent"
  printf "$1" | env -i PATH="$sandbox/path:/usr/bin:/bin" SANDBOX="$sandbox" TERM=dumb \
    timeout 10 bash "$ROOT/bin/desktop-agent-peek" %5 /dev/pts/9 >"$sandbox/screen" 2>&1
}

peek '2q'
check "a digit goes to the agent's pane, as the answer to its prompt" \
  test "$(cat "$sandbox/sent")" = "-t %5 2"
check "its screen is shown" grep -q '1. Yes' "$sandbox/screen"

peek '\nq'
check "Enter goes through as Enter" test "$(cat "$sandbox/sent")" = "-t %5 Enter"

peek 'iuse the other branch\nq'
check "a typed reply is sent as text, then Enter" \
  test "$(paste -sd'|' "$sandbox/sent")" = "-t %5 -l use the other branch|-t %5 Enter"

peek '\e'
check "Esc closes the popup and sends the agent nothing" test ! -s "$sandbox/sent"

peek '\e[Bq'
check "an arrow goes through as the arrow" test "$(cat "$sandbox/sent")" = "-t %5 Down"

peek 'g'
check "g goes to the agent, moving the client that asked" \
  test "$(cat "$sandbox/jumped")" = "jump %5 /dev/pts/9"

peek '1'
check "input that ends closes it, rather than reading as Enter for ever" \
  test "$(cat "$sandbox/sent")" = "-t %5 1"

finish
