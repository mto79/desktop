#!/usr/bin/env bash
# desktop-cluster (ocl): OpenShift, RKE2, Talos and plain Kubernetes clusters, each with a
# kubeconfig of its own.
#
# oc, kubectl, talosctl, ssh, k9s and argo9s are stubs. Their "kubeconfig" is a few
# key=value lines rather than YAML: what is checked is what desktop-cluster asks of them and
# which file it hands on, not what kubectl does with a kubeconfig.
source "$(dirname "$0")/lib.sh"

require jq || finish

CLUSTER="$ROOT/bin/desktop-cluster"
sandbox=$(mktemp -d)
trap 'rm -rf "$sandbox"' EXIT
stubs="$sandbox/stubs"
mkdir -p "$stubs" "$sandbox/config/desktop" "$sandbox/state"
log="$sandbox/calls"

# kubeconfig <file>: the file a stub was pointed at.
cat >"$stubs/kc-lib" <<'LIB'
file=${KUBECONFIG:-}
args=()
while (($#)); do
  case "$1" in
  --kubeconfig) file=$2; shift ;;
  --kubeconfig=*) file=${1#*=} ;;
  --request-timeout=*) ;;
  *) args+=("$1") ;;
  esac
  shift
done
set -- "${args[@]}"
val() { sed -n "s/^$1=//p" "$file" 2>/dev/null | tail -1; }
put() { grep -v "^$1=" "$file" >"$file.n" 2>/dev/null; echo "$1=$2" >>"$file.n"; mv "$file.n" "$file"; }
authed() {
  case "$(val token)" in
  good) return 0 ;;
  down) echo "dial tcp 192.0.2.1:6443: connect: connection refused" >&2; return 1 ;;
  *) echo "error: You must be logged in to the server (Unauthorized)" >&2; return 1 ;;
  esac
}
LIB

cat >"$stubs/kubectl" <<STUB
#!/usr/bin/env bash
source "$stubs/kc-lib"
echo "kubectl \$* @\$file" >>"$log"
case "\$*" in
"config view --raw --flatten --minify") cat "\$file" ;;
"config view --minify -o jsonpath={.clusters[0].name}") val cluster ;;
"config current-context") val context ;;
config\ rename-context*) put context "\$4" ;;
config\ set-cluster*--server*) put server "\$5" ;;
config\ set-cluster*--insecure*) put insecure true ;;
config\ set-context*) put namespace "\$5" ;;
"get --raw /apis") authed ;;
"get nodes -o json")
  authed || exit 1
  if [[ \$(val nodes) == big ]]; then
    # A real cluster's worth: 200 nodes of a kilobyte each, past what one argument may hold.
    pad=\$(printf '%01024d' 0)
    printf '{"items":['
    for i in \$(seq 200); do
      ((i > 1)) && printf ','
      printf '{"metadata":{"annotations":{"x":"%s"}},"status":{"conditions":[{"type":"Ready","status":"True"}]}}' "\$pad"
    done
    printf ']}\n'
  elif [[ \$(val nodes) == half ]]; then
    echo '{"items":[{"status":{"conditions":[{"type":"Ready","status":"True"}]}},{"status":{"conditions":[{"type":"Ready","status":"False"}]}}]}'
  else
    echo '{"items":[{"status":{"conditions":[{"type":"Ready","status":"True"}]}}]}'
  fi ;;
"get clusterversion version -o json") echo '{"status":{"desired":{"version":"4.22.16"},"conditions":[]}}' ;;
"version -o json") echo '{"serverVersion":{"gitVersion":"v1.31.4+rke2r1"}}' ;;
*) exit 1 ;;
esac
STUB

cat >"$stubs/oc" <<STUB
#!/usr/bin/env bash
source "$stubs/kc-lib"
echo "oc \$* @\$file" >>"$log"
case "\$1" in
login)
  [[ -e "$sandbox/refuse" ]] && exit 1
  printf 'context=default/api-x:6443/u\ncluster=api-x:6443\ntoken=good\n' >"\$file"
  for a in "\$@"; do [[ \$a == --server ]] && grab=1 && continue; [[ \${grab:-} ]] && put server "\$a" && grab=""; done ;;
whoami) [[ \${2:-} == --show-console ]] && { echo https://console.ocp202.example; exit; }; authed ;;
logout) ;;
esac
STUB

cat >"$stubs/talosctl" <<STUB
#!/usr/bin/env bash
echo "talosctl \$* TALOSCONFIG=\${TALOSCONFIG:-} KUBECONFIG=\${KUBECONFIG:-}" >>"$log"
for a in "\$@"; do out=\$a; done
[[ " \$* " == *" kubeconfig "* ]] && printf 'context=admin@edge\ncluster=edge\ntoken=good\n' >"\$out"
exit 0
STUB

cat >"$stubs/ssh" <<STUB
#!/usr/bin/env bash
echo "ssh \$*" >>"$log"
printf 'context=default\ncluster=default\nserver=https://127.0.0.1:6443\ntoken=good\n'
STUB

for cmd in k9s argo9s fish xdg-open notify-send; do
  cat >"$stubs/$cmd" <<STUB
#!/usr/bin/env bash
[[ \$1 == --help ]] && { echo "  -n, --namespace string"; exit; }
echo "$cmd \$* KUBECONFIG=\${KUBECONFIG:-} TALOSCONFIG=\${TALOSCONFIG:-} CLUSTER=\${DESKTOP_CLUSTER:-}" >>"$log"
STUB
done
chmod +x "$stubs"/*

printf 'context=lab\ncluster=default\nserver=https://lab.example:6443\ntoken=good\n' >"$sandbox/lab.yaml"
cat >"$sandbox/config/desktop/clusters.conf" <<CONF
# name    kind        how to reach it
ocp202    openshift   server=https://api.ocp202.example:6443   # the old one
ocp203    openshift   server=https://api.ocp203.example:6443 login=token
lab       rke2        ssh=admin@lab-cp1.example namespace=apps
edge      talos       talosconfig=$sandbox/talosconfig nodes=192.0.2.11
kind      kubernetes  kubeconfig=$sandbox/lab.yaml insecure=true
broken    rke2
CONF

run() {
  PATH="$stubs:$PATH" XDG_CONFIG_HOME="$sandbox/config" XDG_STATE_HOME="$sandbox/state" \
    SHELL="$stubs/fish" bash "$CLUSTER" "$@" </dev/null
}
called() { grep -qF -- "$1" "$log"; }
store="$sandbox/state/desktop/clusters"

# --- the list
check "the names are the file's, comments and all left out" \
  test "$(run names | paste -sd' ')" = "ocp202 ocp203 lab edge kind broken"
check "list says each one's kind and where it is" \
  bash -c "$(declare -f run); stubs='$stubs' sandbox='$sandbox' CLUSTER='$CLUSTER'; run list | grep -qE '^lab +rke2 +admin@lab-cp1.example'"
check "a cluster that is not in the file is said to be missing" \
  bash -c "$(declare -f run); stubs='$stubs' sandbox='$sandbox' CLUSTER='$CLUSTER'; run nope 2>&1 | grep -q 'no cluster called nope'"
check "and one missing how to reach it says what it needs" \
  bash -c "$(declare -f run); stubs='$stubs' sandbox='$sandbox' CLUSTER='$CLUSTER'; run broken 2>&1 | grep -q 'needs ssh= or kubeconfig='"

# --- OpenShift
: >"$log"
run ocp202 >/dev/null 2>&1
check "a shell on an OpenShift cluster signs in first, into a kubeconfig of its own" \
  bash -c "grep '^oc login' '$log' | grep -q '@$store/.ocp202.'"
check "at the server in the file" called "--server https://api.ocp202.example:6443"
check "the kubeconfig is named after the cluster" grep -qx 'context=ocp202' "$store/ocp202.kubeconfig"
check "and only its owner can read it" test "$(stat -c %a "$store/ocp202.kubeconfig")" = 600
check "the shell is handed that file and no other" called "fish  KUBECONFIG=$store/ocp202.kubeconfig TALOSCONFIG= CLUSTER=ocp202"
: >"$log"
run ocp202 >/dev/null 2>&1
check "signed in already, it does not sign in again" lacks "oc login" "$log"

# A sign-in that fails leaves the kubeconfig that was there.
sed -i 's/token=good/token=expired/' "$store/ocp202.kubeconfig"
touch "$sandbox/refuse"
run login ocp202 >/dev/null 2>&1
check "a failed sign-in leaves the old kubeconfig, not half a new one" grep -q 'token=expired' "$store/ocp202.kubeconfig"
check "and no scratch file behind" test -z "$(find "$store" -name '.ocp202.*')"
rm "$sandbox/refuse"

# --- RKE2, fetched over ssh
: >"$log"
run -k lab >/dev/null 2>&1
check "an RKE2 cluster's kubeconfig is fetched from its server node" called "ssh admin@lab-cp1.example sudo cat /etc/rancher/rke2/rke2.yaml"
check "with the node's own name in place of 127.0.0.1" grep -qx 'server=https://lab-cp1.example:6443' "$store/lab.kubeconfig"
check "and the namespace it is to start in" grep -qx 'namespace=apps' "$store/lab.kubeconfig"
check "k9s is handed the cluster's own kubeconfig" called "k9s  KUBECONFIG=$store/lab.kubeconfig"

# --- Talos
: >"$log"
run -x edge kubectl get nodes >/dev/null 2>&1
check "a Talos cluster's kubeconfig comes from talosctl, with its talosconfig and node" \
  called "talosctl --talosconfig $sandbox/talosconfig --nodes 192.0.2.11 kubeconfig --force --merge=false $store/.edge."
check "a command runs against it" called "kubectl get nodes @$store/edge.kubeconfig"
: >"$log"
run -t edge >/dev/null 2>&1
check "the Talos dashboard gets the same talosconfig and nodes" \
  called "talosctl --talosconfig $sandbox/talosconfig --nodes 192.0.2.11 dashboard TALOSCONFIG=$sandbox/talosconfig"
check "the Talos dashboard is refused for a cluster that is not Talos" \
  bash -c "$(declare -f run); stubs='$stubs' sandbox='$sandbox' CLUSTER='$CLUSTER'; run -t lab 2>&1 | grep -q 'not talos'"

# --- a kubeconfig of your own
: >"$log"
run -a kind >/dev/null 2>&1
check "a plain kubeconfig is copied, not used in place" test -s "$store/kind.kubeconfig"
check "insecure=true is set in the copy" grep -qx 'insecure=true' "$store/kind.kubeconfig"
check "the original is left as it was" lacks 'insecure' "$sandbox/lab.yaml"
check "Argo CD is looked for in argocd off OpenShift" called "argo9s --namespace argocd KUBECONFIG=$store/kind.kubeconfig"

# --- the environment for the shell you are in
env_out=$(run -e edge 2>/dev/null)
check "-e gives exports to source" grep -qx "export KUBECONFIG=$store/edge.kubeconfig" <<<"$env_out"
check "with the talosconfig for a Talos cluster" grep -qx "export TALOSCONFIG=$sandbox/talosconfig" <<<"$env_out"

# --- status, as the dashboard reads it
printf 'context=ocp202\ncluster=x\ntoken=good\nnodes=half\n' >"$store/ocp202.kubeconfig"
sed -i 's/token=good/token=down/' "$store/kind.kubeconfig"
answer=$(run status --json)
state() { jq -r --arg n "$1" '.[] | select(.name == $n) | .state' <<<"$answer"; }
check "status asks every cluster" test "$(jq length <<<"$answer")" = 6
check "a node not ready is degraded" test "$(state ocp202)" = degraded
check "OpenShift says its version from the cluster version" \
  test "$(jq -r '.[] | select(.name == "ocp202") | .version' <<<"$answer")" = 4.22.16
check "never signed in to is signed out" test "$(state ocp203)" = signed-out

# A cluster the size of a real one: its nodes, as JSON, are past what one argument may hold,
# and handed to jq whole that made it "misconfigured" the moment it was signed in to.
printf 'context=ocp202\ncluster=x\ntoken=good\nnodes=big\n' >"$store/ocp202.kubeconfig"
big=$(run status --json ocp202)
check "a cluster with hundreds of kilobytes of nodes is counted, not called misconfigured" \
  test "$(jq -r '.state + " " + (.nodes|tostring)' <<<"$big")" = "healthy 200"
check "Kubernetes says the API server's version" \
  test "$(jq -r '.[] | select(.name == "lab") | .version' <<<"$answer")" = v1.31.4+rke2r1
check "one that does not answer is unreachable, not signed out" test "$(state kind)" = unreachable
check "one written down wrong is said to be, and the rest are still asked" \
  test "$(state broken) $(state edge)" = "misconfigured healthy"

# --- signing out
run logout ocp202 >/dev/null 2>&1
check "signing out removes that cluster's kubeconfig" test ! -e "$store/ocp202.kubeconfig"
check "and no other" test -e "$store/lab.kubeconfig"

check "a command's name cannot be taken for a cluster" \
  bash -c "$(declare -f run); stubs='$stubs' sandbox='$sandbox' CLUSTER='$CLUSTER'; run -k list 2>&1 | grep -q 'is a command'"

# --- a tmux session on a cluster (prefix + K)
# tmux stubbed: the session is not there yet, then it is, and every call is written down.
cat >"$stubs/tmux" <<STUB
#!/usr/bin/env bash
echo "tmux \$*" >>"$sandbox/tmux-calls"
[[ \$1 == has-session ]] && { [[ -e "$sandbox/has-session" ]]; exit; }
exit 0
STUB
chmod +x "$stubs/tmux"
printf 'context=ocp202\ncluster=x\ntoken=good\n' >"$store/ocp202.kubeconfig"
TMUX=/tmp/fake,1,0 run session ocp202 >/dev/null 2>&1
check "a session named after the cluster is made, with a shell on it" \
  grep -q "^tmux new-session -d -s ocp202 -n shell .*desktop-cluster ocp202\$" "$sandbox/tmux-calls"
check "and k9s beside it" grep -q "^tmux new-window -d -t =ocp202: -n k9s .*desktop-cluster -k ocp202\$" "$sandbox/tmux-calls"
check "and gone to" grep -q '^tmux switch-client -t =ocp202$' "$sandbox/tmux-calls"
: >"$sandbox/tmux-calls"
touch "$sandbox/has-session"
TMUX=/tmp/fake,1,0 run session ocp202 >/dev/null 2>&1
check "a second time it is only gone to" test "$(grep -c 'new-' "$sandbox/tmux-calls")-$(grep -c switch-client "$sandbox/tmux-calls")" = "0-1"
check "prefix + K opens it" grep -q "^bind-key K run-shell \"tmux neww -n cluster 'desktop-cluster session'\"" "$ROOT/config/tmux/tmux.conf"
rm -f "$stubs/tmux"

# --- the migration from the old ocl
MIGRATION="$ROOT/migrations/1794593713.sh"
home="$sandbox/home"
mstubs="$sandbox/mstubs"
mkdir -p "$home/.local/bin" "$home/.local/share/desktop/bin" "$mstubs"
ln -s "$CLUSTER" "$home/.local/share/desktop/bin/desktop-cluster"
ln -s "$ROOT/config" "$home/.local/share/desktop/config"
printf '#!/usr/bin/env bash\nOCL_NAMES=(ocp202 ocp203)\n' >"$home/.local/bin/ocl"
chmod +x "$home/.local/bin/ocl"
cat >"$mstubs/kubectl" <<'STUB'
#!/usr/bin/env bash
case "$*" in
"config view --raw -o json")
  echo '{"contexts":[{"name":"ocp202","context":{"cluster":"api-ocp202-example:6443"}}],
         "clusters":[{"name":"api-ocp202-example:6443","cluster":{"server":"https://api.ocp202.example:6443"}}]}' ;;
"config view --raw --flatten --minify --context ocp202") echo "the ocp202 context, token and all" ;;
*) exit 1 ;;
esac
STUB
printf '#!/usr/bin/env bash\necho talosctl-installed >>"%s/mcalls"\n' "$sandbox" >"$home/.local/share/desktop/bin/desktop-update-releases"
chmod +x "$mstubs/kubectl" "$home/.local/share/desktop/bin/desktop-update-releases"
migrate() { HOME="$home" XDG_CONFIG_HOME="$home/.config" XDG_STATE_HOME="$home/.local/state" PATH="$mstubs:/usr/bin:/bin" bash "$MIGRATION" >/dev/null 2>&1; }
migrate
mconf="$home/.config/desktop/clusters.conf"
check "the old ocl's clusters are carried into clusters.conf" grep -qE '^ocp202 +openshift +server=https://api.ocp202.example:6443$' "$mconf"
check "one with no context to take a server from is left for you, commented" grep -qE '^# ocp203 .*no context' "$mconf"
check "and the file reads as the new one does" \
  test "$(HOME="$home" XDG_CONFIG_HOME="$home/.config" bash "$CLUSTER" names)" = ocp202
check "a sign-in already there is carried over, so it is not asked for again" \
  grep -q 'token and all' "$home/.local/state/desktop/clusters/ocp202.kubeconfig"
check "readable by its owner only" test "$(stat -c %a "$home/.local/state/desktop/clusters/ocp202.kubeconfig")" = 600
check "ocl is now desktop-cluster, as a fish function" grep -q 'desktop-cluster $argv' "$home/.config/fish/functions/ocl.fish"
check "with completions for both names" test -s "$home/.config/fish/completions/desktop-cluster.fish"
check "and the old script is left where it was" grep -q OCL_NAMES "$home/.local/bin/ocl"
check "talosctl is installed for the Talos clusters" grep -q talosctl-installed "$sandbox/mcalls"
echo "# mine" >>"$mconf"
migrate
check "run again, a clusters.conf that is there is left alone" grep -qx '# mine' "$mconf"

finish
