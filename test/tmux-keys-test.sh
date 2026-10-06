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

check "prefix + ? shows it" grep -q '^bind-key ? display-popup .*desktop-tmux-keys' "$CONF"
check "piped, it prints and does not wait for a key" test -n "$("$KEYS" </dev/null)"

finish
