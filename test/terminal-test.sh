#!/usr/bin/env bash
# Ghostty is the only terminal. Alacritty and wezterm were removed, and a reference to
# either is a script that will fail on a machine built from this repo today.
source "$(dirname "$0")/lib.sh"

# Live code only. migrations/ names what it rewrites and the skills explain why the
# terminals went, so both legitimately mention them forever.
for term in alacritty wezterm; do
  hits=$(grep -rli "$term" "$ROOT/bin" "$ROOT/config" "$ROOT/default" "$ROOT/shell" \
    "$ROOT/install" "$ROOT/themes" 2>/dev/null || true)
  if [[ -z $hits ]]; then
    pass "nothing references $term"
  else
    fail "nothing references $term" "$(echo "$hits" | sed "s|$ROOT/||" | tr '\n' ' ')"
  fi
done

# Ghostty cannot set a Wayland app id, so a launcher passing --class is silently
# ignored and its window rule never matches.
hits=$(grep -rn -- "--class" "$ROOT/bin" 2>/dev/null || true)
if [[ -z $hits ]]; then
  pass "no launcher passes --class to ghostty"
else
  fail "no launcher passes --class to ghostty" "$(echo "$hits" | sed "s|$ROOT/||" | tr '\n' ' ')"
fi
# A terminal opened on the tmux workspace is tmux, and a plain shell anywhere else. What
# the launcher would run is recorded by a stub uwsm rather than run.
sandbox=$(mktemp -d)
trap 'rm -rf "$sandbox"' EXIT
mkdir -p "$sandbox/bin"
cat >"$sandbox/bin/hyprctl" <<'STUB'
#!/usr/bin/env bash
echo "{\"id\":$WORKSPACE}"
STUB
cat >"$sandbox/bin/uwsm" <<'STUB'
#!/usr/bin/env bash
echo "$*"
STUB
printf '#!/usr/bin/env bash\necho /somewhere\n' >"$sandbox/bin/desktop-cmd-terminal-cwd"
printf '#!/usr/bin/env bash\n' >"$sandbox/bin/tmux"
chmod +x "$sandbox/bin/"*

launch() {
  WORKSPACE="$1" TERMINAL=term HOME=/home/me PATH="$sandbox/bin:$PATH" "$ROOT/bin/desktop-launch-terminal"
}

check "a terminal on workspace 3 attaches to tmux" \
  test "$(launch 3)" = "app -- term -e tmux new-session -A -s home -c /home/me"
check "a terminal elsewhere is a shell where the last one was" \
  test "$(launch 2)" = "app -- term --working-directory=/somewhere"

# The script only matters while the key runs it.
for bindings in config/hypr/bindings.conf config/hypr/bindings.lua; do
  if grep -q "desktop-launch-terminal" "$ROOT/$bindings"; then
    pass "$bindings opens the terminal through desktop-launch-terminal"
  else
    fail "$bindings opens the terminal through desktop-launch-terminal"
  fi
done
finish
