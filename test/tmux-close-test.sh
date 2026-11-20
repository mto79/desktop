#!/usr/bin/env bash

# desktop-tmux-close: a terminal on a session that closes is moved to a real session first,
# never to an agent column's or a terminal's tabs', which would close it in turn; a client
# inside a pane -- a column's own -- is left to end with its session.

source "$(dirname "$0")/lib.sh"

sandbox=$(mktemp -d)
trap 'rm -rf "$sandbox"' EXIT
mkdir -p "$sandbox/stubs"

# The server: home, then desktop, then the busy helper sessions, most recent last. On the
# helper, a real terminal (/dev/pts/0) -- moved there when its own session closed -- and
# the column's client, whose terminal is a pane (/dev/pts/7).
cat >"$sandbox/stubs/tmux" <<STUB
#!/usr/bin/env bash
echo "tmux \$*" >>"$sandbox/calls"
case \$1 in
has-session) exit 0 ;;
list-sessions) printf '%s\n' '100 home' '300 desktop' '900 ai-work-1-claude' '950 term-work-2' ;;
list-panes) printf '%s\n' /dev/pts/5 /dev/pts/7 ;;
list-clients) printf '%s\n' /dev/pts/0 /dev/pts/7 ;;
esac
exit 0
STUB
chmod +x "$sandbox/stubs/tmux"
: >"$sandbox/calls"
PATH="$sandbox/stubs:$PATH" bash "$ROOT/bin/desktop-tmux-close" ai-work-1-claude

check "a terminal on a session about to close is moved to the latest real session" \
  grep -qxF 'tmux switch-client -c /dev/pts/0 -t =desktop' "$sandbox/calls"
check "  never to another helper, however busy" lacks 'switch-client .* -t =term-' "$sandbox/calls"
check "  and a column's own client, inside a pane, is left alone" lacks 'switch-client -c /dev/pts/7' "$sandbox/calls"
check "  then the session closes" \
  test "$(tail -1 "$sandbox/calls")" = 'tmux kill-session -t =ai-work-1-claude'
check "the columns' and tabs' clean-up closes their sessions this way" \
  test "$(grep -l 'desktop-tmux-close "$session"' "$ROOT/bin/desktop-agent-tabs" "$ROOT/bin/desktop-terminal-tabs" | wc -l)" = 2
check "and so does prefix + q" grep -q 'bind-key q .*desktop-tmux-close' "$ROOT/config/tmux/tmux.conf"

finish
