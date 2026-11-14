#!/usr/bin/env bash
# prefix + ? lists the keys this desktop adds. A list like that is wrong the day after a
# binding is renamed, so every key on it is checked against tmux.conf.
source "$(dirname "$0")/lib.sh"

CONF="$ROOT/config/tmux/tmux.conf"
KEYS="$ROOT/bin/desktop-tmux-keys"

# Every key tmux.conf binds on the prefix, as tmux reads it: "-" and "|" are quoted there,
# "\\" and \` escaped. Compared as text, not as a pattern: half of these keys are regex
# characters.
conf_keys() {
  python3 - "$CONF" <<'PY'
import re, sys
for line in open(sys.argv[1]):
    m = re.match(r'\s*(?:bind-key|bind)\s+((?:-\w\s+)*)(\S+)', line)
    if not m or re.search(r'-[nT]\b', m.group(1)):
        continue
    key = m.group(2)
    if len(key) >= 2 and key[0] == key[-1] and key[0] in "\"'":
        key = key[1:-1].encode().decode("unicode_escape")
    elif len(key) == 2 and key[0] == "\\":
        key = key[1]
    print(key)
PY
}
bound() { grep -qxF -- "$1" <<<"$(conf_keys)"; }

count=0
while IFS=$'\t' read -r key shown what; do
  count=$((count + 1))
  check "prefix + $shown is bound" bound "$key"
  check "prefix + $shown says what it does" test -n "$what"
done < <("$KEYS" --list)
check "the list is not empty" test "$count" -gt 10

# And the other way: a key bound in tmux.conf and missing from the list is one nobody finds.
# Fourteen were, before this check: the splits, the resizing, joining panes, new sessions.
# A key listed once for a pair (C-h for Ctrl+h j k l, < for < >) stands for the others.
listed=$("$KEYS" --list | cut -f1)
for key in $(conf_keys | grep -vxF -e C-j -e C-k -e C-l -e '>' | sort -u); do
  check "prefix + $key, bound in tmux.conf, is on the list" grep -qxF -- "$key" <<<"$listed"
done

# The keys that came with agents, tabs and tasks are the reason the list exists.
for key in t T Tab x a A S g D Z; do
  check "prefix + $key is on the list" grep -qP "^\\Q$key\\E\t" <<<"$("$KEYS" --list)"
done

# The sidebar's own keys, against the keys the sidebar reads. Enter is read as "\n".
SIDEBAR="$ROOT/bin/desktop-tmux-sidebar"
handled() {
  local key=$1
  [[ $key == Enter ]] && key='\n'
  grep -qF "ord(\"$key\")" "$SIDEBAR"
}
count=0
while IFS=$'\t' read -r key shown what; do
  count=$((count + 1))
  check "the sidebar answers to $shown" handled "$key"
  check "and the list says what $shown does there" test -n "$what"
done < <("$KEYS" --sidebar)
check "the sidebar's keys are on the list" test "$count" -ge 5
check "peek and the detailed view among them" \
  test "$("$KEYS" --sidebar | cut -f1 | grep -cx 'p\|v')" = 2
check "they are shown in the popup" grep -q 'In the sidebar' <<<"$("$KEYS" </dev/null)"

check "prefix + ? shows it" grep -q '^bind-key ? display-popup .*desktop-tmux-keys' "$CONF"
check "piped, it prints and does not wait for a key" test -n "$("$KEYS" </dev/null)"

# The keys that destroy. -r lets a key repeat without the prefix for a moment after it, so
# a second w closed a second window; Q took every session and agent without a word.
for key in Q q w x; do
  check "prefix + $key does not repeat" \
    test -z "$(grep -E "^bind(-key)? -r $key " "$CONF")"
done
check "killing the server asks first" grep -qE '^bind-key Q confirm-before .* kill-server$' "$CONF"
check "and so does killing a session" grep -qE '^bind-key q confirm-before .* kill-session$' "$CONF"

# A #() job runs once per client per status-interval, and every agent column is a client.
check "the status line's agent count is asked once for all of them" \
  grep -qF '#(desktop-tmux-cached 5 desktop-agent-sessions --tmux-status)' "$CONF"

finish
