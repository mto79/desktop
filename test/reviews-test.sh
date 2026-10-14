#!/usr/bin/env bash
# Review requests: a popup for each new one, naming who asks and what, opening it on a
# click. What is checked is what goes wrong with several hosts behind a VPN: a host that
# does not answer must not forget what it showed, nor be taken to have no requests; the
# first look at a host must not pop up its whole backlog; your own requests are not news.
#
# glab and gh are stubs answering from files. Nothing here reaches a server or the screen.
source "$(dirname "$0")/lib.sh"

REVIEWS="$ROOT/bin/desktop-reviews"
sandbox=$(mktemp -d)
trap 'rm -rf "$sandbox"' EXIT
stubs="$sandbox/bin" answers="$sandbox/answers"
mkdir -p "$stubs" "$answers"

# glab api --hostname <host> <path>: the file named after the host and what is asked.
cat >"$stubs/glab" <<STUB
#!/usr/bin/env bash
host=\$3 path=\$4
case \$path in
user) echo '{"username": "me"}' ;;
*reviewer_username*) cat "$answers/\$host-review" 2>/dev/null || echo '[]' ;;
*assigned_to_me*) cat "$answers/\$host-assigned" 2>/dev/null || echo '[]' ;;
esac
STUB
cat >"$stubs/gh" <<STUB
#!/usr/bin/env bash
case "\$*" in
*review-requested*) cat "$answers/\$3-review" 2>/dev/null || echo '{"items": []}' ;;
*) echo '{"items": []}' ;;
esac
STUB
# tea logins list / tea api --login <name> <path>
cat >"$stubs/tea" <<STUB
#!/usr/bin/env bash
case "\$1 \$2" in
"logins list") echo '[{"name": "berg", "url": "https://forgejo.example", "user": "me"}]' ;;
"api --login")
  [[ \$3 == berg ]] || exit 1
  case \$4 in
  *review_requested=true*) cat "$answers/forgejo.example-review" 2>/dev/null || echo '[]' ;;
  *) echo '[]' ;;
  esac ;;
esac
STUB
chmod +x "$stubs"/*

mr() { # id author title
  printf '{"id": %s, "iid": %s, "title": "%s", "author": {"username": "%s", "name": "%s"},
           "references": {"full": "team/app!%s"}, "web_url": "https://gitlab.example/team/app/-/merge_requests/%s"}' \
    "$1" "$1" "$3" "$2" "${2^}" "$1" "$1"
}

run() {
  rm -f "$sandbox/sent" "$sandbox/sent.said"
  PATH="$stubs:$PATH" XDG_STATE_HOME="$sandbox/state" DESKTOP_REVIEWS_SEND="$sandbox/sent" \
    DESKTOP_REVIEWS_GITLAB="gitlab.example vpn.example" DESKTOP_REVIEWS_GITHUB="github.example" DESKTOP_REVIEWS_FORGEJO="forgejo.example" \
    DESKTOP_REVIEWS_OFFLINE="${offline:-}" DESKTOP_REVIEWS_CONF="$sandbox/reviews.conf" "$REVIEWS" "$@"
}
sent() { [[ -f $sandbox/sent ]] && grep -c . "$sandbox/sent" || echo 0; }

echo "[$(mr 1 alice 'Old one')]" >"$answers/gitlab.example-review"
run
check "the first look at a host says how many wait, not each of them" test "$(sent)" -eq 1
check "  and opens the list on a click" grep -q 'gitlab.example/dashboard/merge_requests?reviewer_username=me' "$sandbox/sent"

echo "[$(mr 1 alice 'Old one'), $(mr 2 bob 'Fix the login'), $(mr 3 me 'My own')]" >"$answers/gitlab.example-review"
run
check "a new request pops up once" test "$(sent)" -eq 1
check "  saying who asks" grep -q $'\tBob asks for your review\t' "$sandbox/sent"
check "  and what about" grep -q 'Fix the login' "$sandbox/sent"
check "  and opens the request on a click" grep -q '^https://gitlab.example/team/app/-/merge_requests/2'$'\t' "$sandbox/sent"
check "your own request is not news" lacks -q 'My own' "$sandbox/sent"
check "the popup is headed by the forge it came from" grep -q $'\tGitLab$' "$sandbox/sent"
check "and it is said aloud, forge and all" grep -qx 'On GitLab, Bob asks for your review: Fix the login.' "$sandbox/sent.said"

run
check "a request already shown is not shown again" test "$(sent)" -eq 0

offline="gitlab.example" run
check "a host off the VPN is passed over without a word" test "$(sent)" -eq 0
check "  and keeps what it had shown" grep -qx 'gitlab:gitlab.example:2' "$sandbox/state/desktop/reviews/gitlab-gitlab.example"
run
check "  so the VPN coming back brings nothing back" test "$(sent)" -eq 0

echo '{"items": [{"id": 9, "number": 4, "title": "Bump the chart", "user": {"login": "carol"},
       "repository_url": "https://api.github.example/repos/org/chart", "html_url": "https://github.example/org/chart/pull/4"}]}' \
  >"$answers/github.example-review"
mkdir -p "$sandbox/state/desktop/reviews" && : >"$sandbox/state/desktop/reviews/github-github.example"
run
check "a pull request pops up the same way" grep -q $'\tcarol asks for your review\tBump the chart' "$sandbox/sent"
check "  under GitHub's name" grep -q $'\tGitHub$' "$sandbox/sent"
check "  with where it is" grep -q 'org/chart#4' "$sandbox/sent"

# Forgejo, through tea: the login is found by the host in its url, and named to tea.
echo '[{"id": 21, "number": 3, "title": "Typo in the README", "user": {"login": "erin", "full_name": "Erin Smit"},
        "repository": {"full_name": "erin/notes"}, "html_url": "https://forgejo.example/erin/notes/pulls/3"},
       {"id": 22, "number": 4, "title": "Mine", "user": {"login": "me", "full_name": ""},
        "repository": {"full_name": "me/x"}, "html_url": "https://forgejo.example/me/x/pulls/4"}]' \
  >"$answers/forgejo.example-review"
: >"$sandbox/state/desktop/reviews/forgejo-forgejo.example"
run
check "a Forgejo pull request pops up, through tea" grep -q $'^https://forgejo.example/erin/notes/pulls/3\tErin Smit asks for your review\tTypo in the README | Forgejo · erin/notes#3\tForgejo$' "$sandbox/sent"
check "  and your own there is not news either" lacks -q 'Mine' "$sandbox/sent"
echo '[{"id": 23, "number": 5, "title": "feat(chart)!: add the probe", "user": {"login": "erin", "full_name": "Erin Smit"},
        "repository": {"full_name": "erin/notes"}, "html_url": "https://forgejo.example/erin/notes/pulls/5"}]' >"$answers/forgejo.example-review"
run
check "  so feat(chart)!: is not read out" grep -qx 'On Forgejo, Erin Smit asks for your review: add the probe.' "$sandbox/sent.said"
echo 'speak = no' >"$sandbox/reviews.conf"
echo '[{"id": 24, "number": 6, "title": "Quiet one", "user": {"login": "erin", "full_name": ""},
        "repository": {"full_name": "erin/notes"}, "html_url": "https://forgejo.example/erin/notes/pulls/6"}]' >"$answers/forgejo.example-review"
run
check "speak = no keeps the popup and drops the voice" test "$(sent)" -eq 1 -a ! -e "$sandbox/sent.said"
check "  and a Forgejo user with no full name is called by their login" grep -q $'\terin asks for your review\t' "$sandbox/sent"
rm -f "$sandbox/reviews.conf"
offline="forgejo.example" run
check "  and Forgejo off the network is passed over like the rest" grep -qx 'forgejo:forgejo.example:24' "$sandbox/state/desktop/reviews/forgejo-forgejo.example"

run --example
check "--example shows one made-up request from each forge" test "$(sent)" -eq 3
check "  each under its own name" test "$(cut -f4 "$sandbox/sent" | sort | tr '\n' ' ')" = "Forgejo GitHub GitLab "
check "  and says them" test "$(grep -c . "$sandbox/sent.said")" -eq 3
listed=$(PATH="$stubs:$PATH" XDG_STATE_HOME="$sandbox/state" DESKTOP_REVIEWS_GITLAB="gitlab.example" DESKTOP_REVIEWS_GITHUB="" \
  DESKTOP_REVIEWS_FORGEJO="forgejo.example" DESKTOP_REVIEWS_OFFLINE="forgejo.example" "$REVIEWS" --list)
check "--list says what waits on a host" grep -q 'gitlab.example.*waiting for you' <<<"$listed"
check "  and that a host off the VPN did not answer, rather than nothing" grep -q 'forgejo.example.*not reachable' <<<"$listed"

items=""
for i in 10 11 12 13 14 15 16; do items+="${items:+, }$(mr $i dave "Change $i")"; done
echo "[$(mr 1 alice 'Old one'), $(mr 2 bob 'Fix the login'), $items]" >"$answers/gitlab.example-review"
run
check "a backlog arriving at once is one popup, not seven" test "$(sent)" -eq 1

finish
