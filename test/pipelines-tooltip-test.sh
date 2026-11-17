#!/usr/bin/env bash
# The pipelines widget's tooltip, laid out in shell/Bar/widgets/pipelines.js.
#
# It was a list of every merge request, "passed  tb/openshift/ocp-helm-charts!484  Feature:
# ...", the ones with no pipeline among them, wrapping at the tooltip's width. Now: the
# counts in the title, the ones with a pipeline most urgent first, the rest counted.
source "$(dirname "$0")/lib.sh"

require node || finish
# ${#line} below counts characters only in a UTF-8 locale.
export LC_ALL=C.UTF-8

tip() {
  node -e "
    const p = require('$ROOT/shell/Bar/widgets/pipelines.js');
    const rs = JSON.parse(process.argv[1]);
    console.log(p.tooltip(rs, rs.find(r => r.status === 'failed') || rs[0], process.argv[2] === 'stale'));" "$1" "${2:-}"
}

requests='[
 {"status":"success","ref":"tb/openshift/ocp-helm-charts!484","title":"Feature: na-checkmk helm chart"},
 {"status":"none","ref":"tb/openshift/tools-and-scripts!15","title":"feat(mirror): add a mirror"},
 {"status":"failed","ref":"tb/openshift/ocp-helm-charts!549","title":"Draft: feat(na-dependency-track): OWASP Dependency-Track on OpenShift","draft":true},
 {"status":"none","ref":"tb/openshift/tools-and-scripts!14","title":"feat(mirror): another"}
]'
out=$(tip "$requests")

check "the title line counts each outcome" test "$(head -1 <<<"$out")" = "Pipelines  ·  1 failed, 1 passed"
check "  the failed one first, by its project and number, marked a draft" \
  grep -q "^󰅙  ocp-helm-charts !549  draft$" <<<"$out"
check "  its title under it, without the Draft: prefix" grep -q "^   feat(na-dependency-track)" <<<"$out"
# Counted in characters, not bytes: the status glyphs are four bytes each.
check "  no line wider than the tooltip, so nothing wraps" \
  test "$(while IFS= read -r l; do echo "${#l}"; done <<<"$out" | sort -n | tail -1)" -le 40
check "  the group path left out" lacks "tb/openshift" <<<"$out"
check "  merge requests without a pipeline counted, not listed" grep -q "^2 without a pipeline$" <<<"$out"
check "  and not listed" lacks "tools-and-scripts" <<<"$out"
check "  what a click does, last" test "$(tail -1 <<<"$out")" = "Click: failed  ·  right-click: all MRs"
check "GitLab out of reach is said under the title" \
  test "$(sed -n 2p <<<"$(tip "$requests" stale)")" = "GitLab not reachable, as last seen"

finish
