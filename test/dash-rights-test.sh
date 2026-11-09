#!/usr/bin/env bash
# What each coding agent may do, for the Rights heading of the dashboard's AI tab.
#
# A fake /proc and a fake home, so the answers do not depend on what runs here. Checks the
# page's two promises: a limit is only called one when something enforces it, and looking
# at secrets never turns into reading them.
source "$(dirname "$0")/lib.sh"

require python3 || finish
require jq || finish

RIGHTS="$ROOT/bin/desktop-dash-rights"
sandbox=$(mktemp -d)
trap 'rm -rf "$sandbox"' EXIT

home="$sandbox/home"
proc="$sandbox/proc"
stubs="$sandbox/stubs"
mkdir -p "$home/.ssh" "$home/.claude" "$home/.codex" "$home/.config/opencode" "$home/.config/systemd/user" "$proc/self" "$stubs"
mkdir -p "$proc/self/ns" && ln -s 'mnt:[1]' "$proc/self/ns/mnt"

agent() { # pid name ppid no_new_privs seccomp capabilities command...
  local pid=$1 name=$2 ppid=$3 nnp=$4 seccomp=$5 caps=$6
  shift 6
  mkdir -p "$proc/$pid/ns"
  printf 'Name:\t%s\nPPid:\t%s\nCapEff:\t%s\nNoNewPrivs:\t%s\nSeccomp:\t%s\n' "$name" "$ppid" "$caps" "$nnp" "$seccomp" >"$proc/$pid/status"
  printf '%s\0' "$@" >"$proc/$pid/cmdline"
  printf 'PATH=/bin\0DEMO_API_KEY=sekrit-value\0TERM=x\0' >"$proc/$pid/environ"
  ln -s 'mnt:[1]' "$proc/$pid/ns/mnt"
}

agent 100 claude 1 0 0 0000000000000000 claude --allow-dangerously-skip-permissions
agent 200 codex 1 0 0 0000000000000000 codex
agent 300 opencode 1 1 2 0000000000000000 opencode
agent 301 child 100 0 0 0000000000000000 curl

for name in claude codex opencode; do
  printf '#!/bin/sh\n' >"$stubs/$name"
done
cat >"$stubs/ss" <<'STUB'
#!/bin/sh
echo '0 0 192.0.2.1:50000 198.51.100.7:443 users:(("claude",pid=100,fd=3))'
echo '0 0 192.0.2.1:50001 198.51.100.8:443 users:(("curl",pid=301,fd=3))'
echo '0 0 127.0.0.1:50002 127.0.0.1:443 users:(("claude",pid=100,fd=4))'
STUB
printf '#!/bin/sh\nexit 1\n' >"$stubs/systemctl"
chmod +x "$stubs"/*

printf '{"permissions":{"deny":["Read(x)"]},"env":{"ANTHROPIC_BASE_URL":"https://llm.example/v1"}}' >"$home/.claude/settings.json"
printf 'secret' >"$home/.claude/.credentials.json"
printf '[projects."%s"]\ntrust_level = "trusted"\n' "$home" >"$home/.codex/config.toml"
printf '{"provider":{"local":{"options":{"baseURL":"http://host.example:11434/v1"}}}}' >"$home/.config/opencode/opencode.json"
printf 'secret' >"$home/.config/opencode/one.key"

ask() { HOME="$home" DESKTOP_RIGHTS_PROC="$proc" SSH_AUTH_SOCK='' PATH="$stubs:$PATH" python3 "$RIGHTS"; }
answer=$(ask)
of() { jq -r "$1" <<<"$answer"; }
row() { of ".agents[] | select(.key == \"$1\") | .rows[] | select(.section == \"$2\") | .text"; }
gate() { of ".agents[] | select(.key == \"$1\") | .gate.text"; }

check "the answer is one JSON object" jq -e .connected <<<"$answer"
check "an agent with no sandbox is said to have none" test "$(of '.agents[] | select(.key == "claude") | .sandboxed')" = false
check "no_new_privs and seccomp are a sandbox" test "$(of '.agents[] | select(.key == "opencode") | .sandboxed')" = true
check "and only those count" test "$(of '.sandboxed')" = 1
check "a sandboxed agent's files are its policy's" grep -q 'policy lists' <<<"$(row opencode filesystem)"

# The bar a prompt sets is not a boundary: asking first must not read as being held.
check "prompts do not make it sandboxed" grep -q 'switched off inside a session' <<<"$(gate claude)"
agent 101 claude 1 0 0 0000000000000000 claude --dangerously-skip-permissions
answer=$(ask)
check "one session started with no prompts decides the answer" grep -q 'Asks nothing' <<<"$(gate claude)"
rm -rf "${proc:?}/101"

check "Codex's commands have the sandbox it gives them" grep -q 'write only the project' <<<"$(row codex filesystem)"
check "and that is not called a sandbox around Codex itself" test "$(of '.agents[] | select(.key == "codex") | "\(.commands_only)|\(.sandboxed)"')" = "true|false"
agent 201 codex 1 0 0 0000000000000000 codex --dangerously-bypass-approvals-and-sandbox
answer=$(ask)
check "unless started without one, no commands-only label either" test "$(of '.agents[] | select(.key == "codex") | "\(.commands_only)|\(.sandboxed)"')" = "false|false"
check "unless it was started without one" grep -q 'Reads' <<<"$(row codex filesystem)"
rm -rf "${proc:?}/201"
answer=$(ask)
check "a whole home trusted is said out loud" grep -q 'your whole home' <<<"$(of '.agents[] | select(.key == "codex") | .gate.note | join(" ")')"

check "what a child of the agent opens counts, and loopback does not" grep -q '2 hosts now' <<<"$(row claude network)"
check "the host is the one the settings name, and no more than that" test "$(row claude inference)" = llm.example
check "OpenCode's hosts come from its providers" test "$(row opencode inference)" = host.example
check "a key file is listed" grep -q 'opencode/one.key' <<<"$(of '.agents[] | select(.key == "opencode") | .key_files[]')"

check "a secret in the environment is counted by name" test "$(of '.agents[] | select(.key == "claude") | .secrets[0]')" = DEMO_API_KEY
check "and its value goes nowhere" lacks 'sekrit-value' <<<"$answer"
check "a place is tested, and a missing one is left out" test "$(of '[.places[] | select(.label == "SSH keys")] | length') $(of '[.places[] | select(.label == "AWS logins")] | length')" = "1 0"
check "what cannot be read says so" test "$(of '.places[] | select(.label == "System password hashes") | .read')" = false

# A failed sudo -n is a line in the journal the Security tab reads, once a minute.
check "it never tries sudo" lacks -E '"sudo"[, ]+"-n"|sudo -n .*run\(|run\("sudo"' "$RIGHTS"
check "it never starts the keyring by asking" grep -q -- '--auto-start=no' "$RIGHTS"
check "it only reads" lacks -E "open\([^)]*['\"][wa]b?['\"]|os\.remove|shutil\.rm" "$RIGHTS"

check "the dashboard asks for it" grep -q 'rights) desktop-dash-rights' "$ROOT/bin/desktop-dash"
check "only while that heading is looked at" grep -q 'ai.heading === "rights"' "$ROOT/shell/Dashboard/Dashboard.qml"

finish
