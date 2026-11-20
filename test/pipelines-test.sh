#!/usr/bin/env bash

# desktop-pipelines: your merge requests' pipelines from GitLab's GraphQL, the worst of
# them for the bar, and a popup when one finishes.

source "$(dirname "$0")/lib.sh"

sandbox=$(mktemp -d)
trap 'rm -rf "$sandbox"' EXIT
mkdir -p "$sandbox/stubs" "$sandbox/run"

# glab: answers with $sandbox/<host>.json, or fails when there is none.
cat >"$sandbox/stubs/glab" <<STUB
#!/usr/bin/env bash
[[ \$1 == api && \$2 == graphql ]] || exit 1
host=\$4
[[ -f "$sandbox/\$host.json" ]] || exit 1
cat "$sandbox/\$host.json"
STUB
chmod +x "$sandbox/stubs/glab"

# answer <host> <status of !1> [<status of !2>]: what GitLab says, a merge request a status.
answer() {
  local host=$1 one=$2 two=${3:-}
  jq -n --arg one "$one" --arg two "$two" '
    def mr($iid; $s): {iid: $iid, title: "feat: thing \($iid)", webUrl: "https://git.example/g/p/-/merge_requests/\($iid)",
      draft: false, project: {fullPath: "g/p"},
      headPipeline: (if $s == "NONE" then null else {id: "gid://gitlab/Ci::Pipeline/\($iid)0", status: $s, path: "/g/p/-/pipelines/\($iid)0"} end)};
    {data: {currentUser: {username: "u", authoredMergeRequests: {nodes:
      ([mr("1"; $one)] + (if $two == "" then [] else [mr("2"; $two)] end))}}}}' >"$sandbox/$host.json"
}

pipes() {
  env -i PATH="$sandbox/stubs:/usr/bin:/bin" HOME="$sandbox/home" XDG_RUNTIME_DIR="$sandbox/run" \
    DESKTOP_PIPELINES_GITLAB="${HOSTS:-git.example}" DESKTOP_PIPELINES_OFFLINE="${OFFLINE:-}" \
    DESKTOP_PIPELINES_SEND="$sandbox/sent" bash "$ROOT/bin/desktop-pipelines" "$@" 2>&1
}
out="$sandbox/run/desktop/pipelines.json"
: >"$sandbox/sent"

answer git.example RUNNING SUCCESS
pipes
check "your merge requests are read, with their pipeline's status" \
  test "$(jq -r '[.requests[].status] | join(" ")' "$out")" = "running success"
check "  the worst of them is what the bar shows: running before passed" test "$(jq -r .worst "$out")" = running
check "  a pipeline's link is the host's own" \
  test "$(jq -r '.requests[0].pipelineUrl' "$out")" = "https://git.example/g/p/-/pipelines/10"
check "the first check has nothing to compare with, and says nothing" test ! -s "$sandbox/sent"

answer git.example FAILED SUCCESS
pipes
check "a pipeline that was running and failed is a popup" grep -q $'^https://git.example/g/p/-/pipelines/10\tPipeline failed: g/p!1\tfeat: thing 1$' "$sandbox/sent"
check "  and one that had passed already is not" test "$(grep -c . "$sandbox/sent")" = 1
check "  failed beats everything in the bar" test "$(jq -r .worst "$out")" = failed
: >"$sandbox/sent"
pipes
check "told once, not every minute after" test ! -s "$sandbox/sent"

answer git.example WAITING_FOR_RESOURCE MANUAL
pipes
check "waiting to start, or for a manual job, is waiting" test "$(jq -r '[.requests[].status] | join(" ")' "$out")" = "pending pending"
answer git.example SUCCESS NONE
pipes
check "waiting and then passed is a popup too" grep -q $'Pipeline passed: g/p!1' "$sandbox/sent"
check "a merge request with no pipeline is listed as none" test "$(jq -r '.requests[1].status' "$out")" = none

OFFLINE=git.example pipes
check "a host off the VPN keeps what it said, marked as such" \
  test "$(jq -r '[.requests[] | "\(.status):\(.stale)"] | join(" ")' "$out")" = "success:true none:true"
check "  and the host is said to be unreachable" test "$(jq -r '.hosts[0].state' "$out")" = unreachable

jq '.data.currentUser.authoredMergeRequests.nodes[0] |= (.draft = true | .title = "Draft: idea" | .headPipeline.status = "MANUAL")' \
  "$sandbox/git.example.json" >"$sandbox/d.json" && mv "$sandbox/d.json" "$sandbox/git.example.json"
pipes
check "a draft whose pipeline waits does not colour the mark" test "$(jq -r .worst "$out")" = none
sed -i 's/"MANUAL"/"FAILED"/' "$sandbox/git.example.json"
pipes
check "  but one that failed does" test "$(jq -r .worst "$out")" = failed
check "a draft is listed with GitLab's own title, its Draft: said once" \
  test "$(pipes --list | grep -c 'Draft: idea')-$(pipes --list | grep -c 'Draft: Draft:')" = 1-0

# Someone else's merge request, waiting for your review, failing: listed, never the mark.
jq '.data.currentUser.reviewRequestedMergeRequests.nodes = [{iid: "7", title: "fix: theirs", webUrl: "https://git.example/g/q/-/merge_requests/7",
      draft: false, updatedAt: "2026-11-20T10:00:00Z", author: {username: "bo", name: "Bo Smit"}, project: {fullPath: "g/q"},
      headPipeline: {id: "gid://gitlab/Ci::Pipeline/70", status: "RUNNING", path: "/g/q/-/pipelines/70"}}]
    | .data.currentUser.assignedMergeRequests.nodes = [.data.currentUser.authoredMergeRequests.nodes[0] + {author: {username: "u"}}]
    | .data.currentUser.authoredMergeRequests.nodes[0].headPipeline.status = "SUCCESS"' \
  "$sandbox/git.example.json" >"$sandbox/r.json" && mv "$sandbox/r.json" "$sandbox/git.example.json"
pipes
check "a merge request waiting for your review is listed, with who asks" \
  test "$(jq -r '.requests[] | select(.role == "review") | "\(.ref) \(.author)"' "$out")" = "g/q!7 Bo Smit"
check "  your own, assigned to you, is not counted twice" test "$(jq -r '[.requests[] | select(.role == "review")] | length' "$out")" = 1
check "  its running pipeline does not colour the mark" test "$(jq -r .worst "$out")" = none
sed -i 's/"RUNNING"/"FAILED"/' "$sandbox/git.example.json"
: >"$sandbox/sent"
pipes
check "  nor pops up when it finishes" test ! -s "$sandbox/sent"
check "  and --list shows it under its own heading" grep -q "waiting for your review" <<<"$(pipes --list)"

rm "$sandbox/git.example.json"
echo '{"requests": [], "worst": "none"}' >"$out"
pipes
check "a host that answers with nothing is nothing to show" test "$(jq -r .worst "$out")" = none

check "the bar knows the widget" grep -q '"pipelines": pipelines' "$ROOT/shell/Bar/WidgetRegistry.qml"
check "  and the default layout has it, beside security" \
  grep -q '"id": "pipelines"' "$ROOT/config/desktop/shell.json"

finish
