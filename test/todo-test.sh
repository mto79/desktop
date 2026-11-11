#!/usr/bin/env bash
# The to-do list and the note on the dashboard's start page. What is checked: items are
# added, ticked off and back, removed one at a time or all the done ones at once; a text
# with quotes survives; the note is replaced whole, from an argument or stdin; and nothing
# is written for an empty item.
source "$(dirname "$0")/lib.sh"

require jq || finish

sandbox=$(mktemp -d)
trap 'rm -rf "$sandbox"' EXIT
todo() { XDG_STATE_HOME="$sandbox" bash "$ROOT/bin/desktop-todo" "$@"; }
items() { todo --json | jq -c '[.items[] | [.id, .text, .done]]'; }

check "with nothing written yet, the list is empty and so is the note" \
  test "$(todo --json)" = '{"items":[],"notes":""}'

todo add 'buy "milk"'
todo add second item
check "items are added in order, numbered, with what they say kept as it was" \
  test "$(items)" = '[[1,"buy \"milk\"",false],[2,"second item",false]]'

todo done 1
check "an item is ticked off" test "$(items)" = '[[1,"buy \"milk\"",true],[2,"second item",false]]'
todo done 1
check "and back" test "$(items)" = '[[1,"buy \"milk\"",false],[2,"second item",false]]'

todo add third
todo remove 2
check "one item is removed, the rest keep their numbers" test "$(items)" = '[[1,"buy \"milk\"",false],[3,"third",false]]'
todo add fourth
check "and a new one takes the number after the highest" test "$(todo --json | jq -c '[.items[].id]')" = '[1,3,4]'

todo done 1
todo done 4
todo clear
check "clearing takes away what is done, and only that" test "$(items)" = '[[3,"third",false]]'

todo add "   " 2>/dev/null && status=0 || status=$?
check "an empty item is refused" test "$status" != 0
check "and nothing is added" test "$(todo --json | jq '.items | length')" = 1

todo notes $'first line\nsecond line'
check "the note is written whole" test "$(todo --json | jq -r .notes)" = $'first line\nsecond line'
printf 'from stdin' | todo notes -
check "and replaced, from stdin as well" test "$(todo --json | jq -r .notes)" = "from stdin"

check "the start page reads the list" grep -q 'todo.json' "$ROOT/shell/Dashboard/StartPage.qml"
check "and writes through this script" grep -q '"desktop-todo", "add"' "$ROOT/shell/Dashboard/StartPage.qml"

finish
