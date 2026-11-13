#!/usr/bin/env bash
# desktop-agent-cluster-guard: Claude Code asks before an agent touches a cluster.
#
# What is checked is the line it draws: every way a command reaches a cluster asks, and a
# command that only mentions one -- grep oc, echo kubectl -- does not, since a guard that
# asks for everything is a guard nobody reads. And it must never break an agent: input it
# cannot read is let through.
source "$(dirname "$0")/lib.sh"

require jq || finish

GUARD="$ROOT/bin/desktop-agent-cluster-guard"
sandbox=$(mktemp -d)
trap 'rm -rf "$sandbox"' EXIT
printf 'ocp204 openshift server=https://api.ocp204.example:6443 prod=true\nlab rke2 ssh=admin@lab.example\n' >"$sandbox/clusters.conf"

# decide <tool> <command or path> [cluster]: what the guard answers, "ask" or nothing.
decide() {
  jq -cn --arg t "$1" --arg c "$2" '{tool_name: $t, tool_input: (if $t == "Bash" then {command: $c} else {file_path: $c} end)}' |
    env -u DESKTOP_CLUSTER -u KUBECONFIG ${3:+DESKTOP_CLUSTER=$3} DESKTOP_CLUSTERS="$sandbox/clusters.conf" bash "$GUARD" |
    jq -r '.hookSpecificOutput.permissionDecision // empty' 2>/dev/null
}
reason() {
  jq -cn --arg c "$1" '{tool_name: "Bash", tool_input: {command: $c}}' |
    env -u KUBECONFIG DESKTOP_CLUSTER="$2" DESKTOP_CLUSTERS="$sandbox/clusters.conf" bash "$GUARD" |
    jq -r '.hookSpecificOutput.permissionDecisionReason'
}
asks() { test "$(decide "$@")" = ask; }
quiet() { test -z "$(decide "$@")"; }

check "kubectl asks" asks Bash "kubectl get pods"
check "every time, a read as much as a change" asks Bash "kubectl get secret -o yaml"
check "after && as well as first" asks Bash "cd deploy && kubectl apply -f ."
check "after a pipe" asks Bash "cat x.yaml | kubectl apply -f -"
check "inside \$( )" asks Bash 'echo $(kubectl get ns)'
check "on a line of its own in a script" asks Bash $'set -e\ntalosctl dashboard'
check "behind sudo with a flag" asks Bash "sudo -E kubectl get nodes"
check "behind env with a variable" asks Bash "env KUBECONFIG=/tmp/x oc whoami"
check "by its path" asks Bash "/usr/local/bin/helm list -A"
check "under watch" asks Bash "watch -n 2 kubectl get pods"
for tool in oc helm k9s talosctl argocd flux ocl desktop-cluster kubie; do
  check "$tool asks" asks Bash "$tool version"
done
check "a kubeconfig read with cat asks" asks Bash "cat ~/.kube/config"
check "and so does one named in a variable" asks Bash 'KUBECONFIG=$HOME/x.yaml some-tool'
check "opening a kubeconfig with Read asks" asks Read "/home/u/.local/state/desktop/clusters/lab.kubeconfig"
check "and a talosconfig" asks Read "/home/u/.talos/config"

check "grep oc is not oc" quiet Bash "git log | grep oc"
check "searching for kubectl is not running it" quiet Bash "grep -rn kubectl docs/"
check "echo ocl is not ocl" quiet Bash "echo ocl"
check "a word that starts with a tool's name is not it" quiet Bash "helmet build && ocaml x.ml"
check "an ordinary command is let through" quiet Bash "npm test"
check "an ordinary file is let through" quiet Read "/w/README.md"

check "the prompt names the cluster the agent is on" grep -q 'cluster lab)' <<<"$(reason "kubectl get po" lab)"
check "and says when it is production" grep -q 'PRODUCTION cluster ocp204' <<<"$(reason "kubectl get po" ocp204)"
check "with no cluster set, it says it is whatever ~/.kube/config points at" \
  grep -q '~/.kube/config' <<<"$(reason "kubectl get po" "")"

check "input it cannot read is let through" test -z "$(echo 'not json' | bash "$GUARD")"
check "and it exits 0 whatever it was given" bash -c "echo 'not json' | bash '$GUARD'; test \$? = 0"

finish
