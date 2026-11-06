#!/usr/bin/env bash
# desktop-tmux-cached: the AI columns' bar jobs, run at most once per ttl.
#
# tmux asks for each #() once per client per status-interval. Run every time, the two
# Python scripts behind the bar took two cores between them; this is what stops that.
source "$(dirname "$0")/lib.sh"

sandbox=$(mktemp -d)
trap 'rm -rf "$sandbox"' EXIT

cat >"$sandbox/count" <<'STUB'
#!/usr/bin/env bash
n=$(($(cat "$SANDBOX/runs" 2>/dev/null || echo 0) + 1))
echo "$n" >"$SANDBOX/runs"
printf 'run %s · %s' "$n" "$*"
[[ -e $SANDBOX/fail ]] && exit 1
exit 0
STUB
chmod +x "$sandbox/count"

cached() { # ttl args...
  env -i PATH=/usr/bin:/bin XDG_RUNTIME_DIR="$sandbox/run" SANDBOX="$sandbox" \
    bash "$ROOT/bin/desktop-tmux-cached" "$@"
}
mkdir -p "$sandbox/run"

check "the first call runs the command and prints what it printed" \
  test "$(cached 30 "$sandbox/count" --agent claude)" = "run 1 · --agent claude"
check "a call within the ttl prints the same without running it again" \
  test "$(cached 30 "$sandbox/count" --agent claude)" = "run 1 · --agent claude"
check "a different command line is a different answer" \
  test "$(cached 30 "$sandbox/count" --agent opencode)" = "run 2 · --agent opencode"
check "once the ttl is up it runs again" \
  test "$(cached 0 "$sandbox/count" --agent claude)" = "run 3 · --agent claude"

lock=$(echo "$sandbox/run/desktop-tmux-cached/"*claude).lock
mkdir "$lock"
check "while another call is making it, a stale answer is printed rather than a second run" \
  test "$(cached 0 "$sandbox/count" --agent claude)" = "run 3 · --agent claude"
touch -d '10 minutes ago' "$lock"
check "and a lock left behind by a run that died is taken over" \
  test "$(cached 0 "$sandbox/count" --agent claude)" = "run 4 · --agent claude"
check "and let go of afterwards" test ! -e "$lock"

touch "$sandbox/fail"
cached 30 "$sandbox/count" --offline >/dev/null
rm "$sandbox/fail"
check "a failed run is not kept, so the next call tries again" \
  test "$(cached 30 "$sandbox/count" --offline)" = "run 6 · --offline"

check "the AI column's bar goes through it" \
  test "$(grep -c '#(desktop-tmux-cached 30 desktop-' "$ROOT/config/tmux/tmux.conf")" = 1
check "for both of its jobs" \
  test "$(grep -o '#(desktop-tmux-cached 30 desktop-' "$ROOT/config/tmux/tmux.conf" | wc -l)" = 2

finish
