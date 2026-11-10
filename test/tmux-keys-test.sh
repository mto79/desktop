#!/usr/bin/env bash
# prefix + ? lists the keys this desktop adds. A list like that is wrong the day after a
# binding is renamed, so every key on it is checked against tmux.conf.
source "$(dirname "$0")/lib.sh"

CONF="$ROOT/config/tmux/tmux.conf"
KEYS="$ROOT/bin/desktop-tmux-keys"

# Compared as text, not as a pattern: half of these keys are regex characters.
bound() {
  awk -v key="$1" '
    BEGIN { n = split("bind-key |bind-key -r |bind |bind -r |bind -n ", lead, "|") }
    { for (i = 1; i <= n; i++) if (index($0, lead[i] key " ") == 1) found = 1 }
    END { exit !found }' "$CONF"
}

count=0
while IFS=$'\t' read -r key shown what; do
  count=$((count + 1))
  check "prefix + $shown is bound" bound "$key"
  check "prefix + $shown says what it does" test -n "$what"
done < <("$KEYS" --list)
check "the list is not empty" test "$count" -gt 10

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
