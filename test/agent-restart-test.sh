#!/usr/bin/env bash
# OpenCode's renderer dies of SIGILL when the display scale under it changes, and every
# agent pane dies with it on a docked login. desktop-agent starts it again, back into its
# conversation. What is checked: that it does, that it leaves a session it was given
# alone, that it stops when the crash is a loop, and that nothing else is restarted.
#
# The agents are stubs that kill themselves with SIGILL. Nothing here starts a real one.
source "$(dirname "$0")/lib.sh"

AGENT="$ROOT/bin/desktop-agent"
sandbox=$(mktemp -d)
trap 'rm -rf "$sandbox"' EXIT
stubs="$sandbox/bin"
mkdir -p "$stubs" "$sandbox/work"

# <name>: dies of SIGILL while $sandbox/crashes says so, one fewer each time, and writes
# down what it was started with.
for name in opencode claude; do
  cat >"$stubs/$name" <<STUB
#!/usr/bin/env bash
echo "\$*" >>"$sandbox/runs"
left=\$(cat "$sandbox/crashes" 2>/dev/null || echo 0)
if ((left > 0)); then
  echo \$((left - 1)) >"$sandbox/crashes"
  kill -ILL \$\$
fi
STUB
done
printf '#!/usr/bin/env bash\necho "$*" >>"%s/notified"\n' "$sandbox" >"$stubs/notify-send"
printf '#!/usr/bin/env bash\n:\n' >"$stubs/sleep"
chmod +x "$stubs"/*

# run <crashes> <agent> [args...]: the exit code; the runs and notifications are in files.
run() {
  rm -f "$sandbox/runs" "$sandbox/notified"
  echo "$1" >"$sandbox/crashes"
  shift
  (cd "$sandbox/work" && PATH="$stubs:$PATH" DESKTOP_AGENT_MIN_UP=0 "$AGENT" "$@" 2>/dev/null)
}

run 2 opencode
code=$?
check "opencode that crashes twice is started again until it stays up" test "$(wc -l <"$sandbox/runs")" -eq 3
check "  and goes back into its conversation" test "$(sed -n 2,3p "$sandbox/runs")" = $'--continue\n--continue'
check "  and the pane ends as cleanly as opencode did" test "$code" -eq 0
check "  without a notification" test ! -e "$sandbox/notified"

run 1 opencode --session ses_1
check "a session it was given is the one it is started on again" test "$(sed -n 2p "$sandbox/runs")" = "--session ses_1"

run 9 opencode
code=$?
check "a crash that keeps coming back is a loop, and is left alone" test "$(wc -l <"$sandbox/runs")" -eq 4
check "  with the signal in the notification" grep -q 'killed by signal 4' "$sandbox/notified"
check "  and the pane's exit code" test "$code" -eq 132

rm -f "$sandbox/runs"
echo 1 >"$sandbox/crashes"
(cd "$sandbox/work" && PATH="$stubs:$PATH" DESKTOP_AGENT_MIN_UP=60 "$AGENT" opencode 2>/dev/null)
check "a crash before it was ever up is not restarted" test "$(wc -l <"$sandbox/runs")" -eq 1

run 1 claude
check "only opencode is restarted" test "$(wc -l <"$sandbox/runs")" -eq 1

finish
