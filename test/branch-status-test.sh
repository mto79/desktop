#!/usr/bin/env bash
# desktop-branch-status: what a checkout changed, and the review it is in.
#
# The count must cover what the branch changed, committed or not, and nothing the default
# branch did meanwhile. The review is the forge's, so its answer is folded into one word
# the sidebar can colour -- and a forge that does not answer, as one behind a VPN does
# not, must leave what it said last alone rather than wipe the review off the row.
source "$(dirname "$0")/lib.sh"

require python3 || finish
require git || finish

sandbox=$(mktemp -d)
trap 'rm -rf "$sandbox"' EXIT
mkdir -p "$sandbox/path" "$sandbox/runtime"

run() {
  env -i PATH="$sandbox/path:/usr/bin:/bin" HOME="$sandbox" XDG_RUNTIME_DIR="$sandbox/runtime" \
    SANDBOX="$sandbox" GLAB="${GLAB:-}" GIT_CONFIG_NOSYSTEM=1 "$@"
}

# A repository with a default branch on origin, and a branch two commits and some
# uncommitted work away from it.
g() { run git -c user.name=u -c user.email=u@host.example -c init.defaultBranch=main "$@"; }
g init -q --bare "$sandbox/origin.git"
g clone -q "$sandbox/origin.git" "$sandbox/repo" 2>/dev/null
seq 1 10 >"$sandbox/repo/file"
g -C "$sandbox/repo" add file
g -C "$sandbox/repo" commit -qm first
g -C "$sandbox/repo" push -q origin main 2>/dev/null
g -C "$sandbox/repo" remote set-head origin main
g -C "$sandbox/repo" switch -qc fix-runner
seq 1 12 >"$sandbox/repo/file"
g -C "$sandbox/repo" commit -qam second
sed -i 1d "$sandbox/repo/file"

status() { run python3 "$ROOT/bin/desktop-branch-status" "$@"; }
forge() { # dir branch: what the background half does, run in the foreground
  local cache
  cache=$(ls "$sandbox/runtime/desktop/branch-status/"*.json | head -1)
  run python3 "$ROOT/bin/desktop-branch-status" --forge "$1" "$2" "$cache"
}

# glab, answering as $GLAB says: a review, none, or no answer at all.
cat >"$sandbox/path/glab" <<'STUB'
#!/usr/bin/env bash
case $GLAB in
review) echo '{"iid":12,"state":"opened","web_url":"https://host.example/r/-/merge_requests/12","head_pipeline":{"status":"failed"}}' ;;
none) echo 'no open merge request available for "fix-runner"' >&2; exit 1 ;;
*) echo 'dial tcp: i/o timeout' >&2; exit 1 ;;
esac
STUB
cat >"$sandbox/path/gh" <<'STUB'
#!/usr/bin/env bash
echo '{"number":7,"state":"OPEN","url":"https://github.com/o/r/pull/7","statusCheckRollup":[{"status":"COMPLETED","conclusion":"SUCCESS"},{"status":"IN_PROGRESS","conclusion":""}]}'
STUB
chmod +x "$sandbox/path/glab" "$sandbox/path/gh"
g -C "$sandbox/repo" remote set-url origin git@host.example:r.git

first=$(status "$sandbox/repo")
# That first look set the forge asking in the background. It is let finish, or its answer
# could land after the ones below and overwrite them.
settle() {
  for _ in $(seq 50); do
    compgen -G "$sandbox/runtime/desktop/branch-status/*.asking" >/dev/null || return 0
    sleep 0.1
  done
}
settle
check "the forge is asked in the background, and lets go when it is done" \
  test -z "$(compgen -G "$sandbox/runtime/desktop/branch-status/*.asking")"
check "it names the branch" test "$(jq -r .branch <<<"$first")" = fix-runner
check "it counts the branch's commits and its uncommitted work together" \
  test "$(jq -r '"\(.added) \(.removed)"' <<<"$first")" = "2 1"
check "and has no review before the forge has been asked" test "$(jq -r .review <<<"$first")" = null

GLAB=review forge "$sandbox/repo" fix-runner
check "a merge request's number and failed pipeline are kept" \
  test "$(status "$sandbox/repo" | jq -r '.review | "\(.number) \(.state) \(.checks)"')" = "12 opened failed"

GLAB=timeout forge "$sandbox/repo" fix-runner
check "a forge that does not answer leaves the review it gave before" \
  test "$(status "$sandbox/repo" | jq -r .review.number)" = 12

GLAB=none forge "$sandbox/repo" fix-runner
check "a forge that says there is none takes it away" \
  test "$(status "$sandbox/repo" | jq -r .review)" = null

rm -rf "$sandbox/runtime/desktop/branch-status"
g -C "$sandbox/repo" remote set-url origin git@github.com:o/r.git
status "$sandbox/repo" >/dev/null
settle
forge "$sandbox/repo" fix-runner
check "on GitHub, a check still running outweighs one that passed" \
  test "$(status "$sandbox/repo" | jq -r '.review | "\(.number) \(.checks)"')" = "7 running"

g -C "$sandbox/repo" switch -q main 2>/dev/null
rm -rf "$sandbox/runtime/desktop/branch-status"
check "the default branch has no review to show" \
  test "$(status "$sandbox/repo" | jq -r .review)" = null
check "a directory that is no repository gives an empty answer" \
  test "$(status "$sandbox/nowhere")" = "{}"

finish
