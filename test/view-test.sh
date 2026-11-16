#!/usr/bin/env bash

# desktop-view: the views a sidebar lists, and a session made for one only once.

source "$(dirname "$0")/lib.sh"

sandbox=$(mktemp -d)
trap 'rm -rf "$sandbox"' EXIT
mkdir -p "$sandbox/path" "$sandbox/config/desktop"

# A tmux where only "reviews" is open; what is asked of it is written down.
cat >"$sandbox/path/tmux" <<'STUB'
#!/usr/bin/env bash
echo "$*" >>"$SANDBOX/did"
[[ $* == "has-session -t =reviews" ]] && exit 0
[[ $1 == has-session ]] && exit 1
exit 0
STUB
cat >"$sandbox/path/desktop-agent-layout" <<'STUB'
#!/usr/bin/env bash
echo "desktop-agent-layout $*" >>"$SANDBOX/did"
STUB
chmod +x "$sandbox/path/tmux" "$sandbox/path/desktop-agent-layout"

cat >"$sandbox/config/desktop/views.conf" <<'EOF2'
# a comment, and a blank line after it

reviews   desktop-view watch 300 desktop-reviews --list
  update	desktop-update --yes
notes     dir=~/Data/notes  desktop-view watch 60 ls
EOF2

view() {
  env -i PATH="$sandbox/path:/usr/bin:/bin" HOME=/home/u SANDBOX="$sandbox" \
    DESKTOP_VIEW_AGENT_HOME="$sandbox/views" \
    XDG_CONFIG_HOME="$sandbox/config" "$ROOT/bin/desktop-view" "$@" 2>&1
}

check "the views are listed by name, comments and blank lines left out" \
  test "$(view names | tr '\n' ,)" = "reviews,update,notes,"
check "the repository's own list is there, for before there is one" \
  test -s "$ROOT/config/desktop/views.conf"
check "  and each of its commands is one that exists" \
  bash -c "sed -E '/^(#|\$)/d' '$ROOT/config/desktop/views.conf' | awk '{print \$2}' |
    while read -r c; do command -v \"\$c\" >/dev/null || [[ -x '$ROOT/bin/'\$c ]] || exit 1; done"

: >"$sandbox/did"
view start update >/dev/null
check "a view not open is made, a session named after it running the view" \
  grep -qE "^new-session -d -s update -n update -c $sandbox/views/update .*desktop-view run update$" "$sandbox/did"
check "in a folder of the view's own, which is made" test -d "$sandbox/views/update"
check "with an agent column on the right, the column alone" \
  grep -qx "desktop-agent-layout --column =update:update claude" "$sandbox/did"
check "and marked as a view, so a restore leaves it to desktop-view" \
  grep -qx "set-option -t =update: @view update" "$sandbox/did"
: >"$sandbox/did"
view start reviews >/dev/null
: >"$sandbox/did"
view start notes >/dev/null
check "a view with dir= works there instead, ~ for home" \
  grep -qE "^new-session -d -s notes -n notes -c /home/u/Data/notes .*desktop-view run notes$" "$sandbox/did"
check "  and runs its command without it" \
  test "$(env -i PATH=/usr/bin:/bin XDG_CONFIG_HOME="$sandbox/config" bash -c "source <(sed -n '/^views()/,/^}/p;/^command_of()/,/^}/p' '$ROOT/bin/desktop-view'); CONFIG='$sandbox/config/desktop/views.conf'; command_of notes")" = "desktop-view watch 60 ls"
: >"$sandbox/did"
view start reviews >/dev/null
check "one already open is left as it is" lacks new-session "$sandbox/did"
check "an unknown view is refused" grep -q "no view called 'nope'" <<<"$(view start nope)"

: >"$sandbox/did"
env -i PATH="$sandbox/path:/usr/bin:/bin" HOME=/home/u SANDBOX="$sandbox" TMUX=x \
  XDG_CONFIG_HOME="$sandbox/config" "$ROOT/bin/desktop-view" open reviews >/dev/null 2>&1
check "opened from inside tmux, it is switched to" grep -qx "switch-client -t =reviews" "$sandbox/did"

finish
