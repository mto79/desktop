#!/usr/bin/env bash

# desktop-agent-guard: the private places denied to Claude Code and opencode, merged into
# settings that hold more than this, and nothing that was there lost.

source "$(dirname "$0")/lib.sh"

sandbox=$(mktemp -d)
trap 'rm -rf "$sandbox"' EXIT
mkdir -p "$sandbox/claude" "$sandbox/config/opencode"
printf '# a comment\n~/.ssh/**\n\n~/.config/gh/hosts.yml\n~/**/*.kdbx\n' >"$sandbox/paths"
echo '{"hooks": {"Stop": []}, "permissions": {"deny": ["Bash(rm -rf *)"]}}' >"$sandbox/claude/settings.json"
echo '{"provider": {"x": {}}, "permission": {"bash": {"*": "allow"}}}' >"$sandbox/config/opencode/opencode.json"

guard() {
  env -i PATH=/usr/bin:/bin HOME="$sandbox/home" CLAUDE_CONFIG_DIR="$sandbox/claude" \
    XDG_CONFIG_HOME="$sandbox/config" DESKTOP_AGENT_PRIVATE="$sandbox/paths" \
    bash "$ROOT/bin/desktop-agent-guard" "$@" 2>&1
}
claude="$sandbox/claude/settings.json"
opencode="$sandbox/config/opencode/opencode.json"

guard --check >/dev/null; checked=$?
check "missing rules are reported before they are added" test "$checked" = 1
guard >/dev/null
check "Claude Code is denied reading and editing each place" \
  test "$(jq -c '[.permissions.deny[] | select(startswith("Read(") or startswith("Edit("))] | length' "$claude")" = 6
check "  as written: ~ and ** kept for Claude's own matching" \
  jq -e '.permissions.deny | index("Read(~/.ssh/**)") and index("Edit(~/**/*.kdbx)")' "$claude"
check "  its own rules kept" jq -e '.permissions.deny | index("Bash(rm -rf *)")' "$claude"
check "  and the rest of its settings" jq -e '.hooks.Stop' "$claude"
check "opencode is denied reading and editing each place, in its own pattern" \
  test "$(jq -c '[.permission.read["~/.ssh/*"], .permission.edit["~/*.kdbx"]]' "$opencode")" = '["deny","deny"]'
check "  everything else still allowed" test "$(jq -r '.permission.read["*"]' "$opencode")" = allow
check "  and its providers kept" jq -e '.provider.x' "$opencode"
before=$(cat "$claude" "$opencode")
guard >/dev/null
check "run again, nothing changes" test "$before" = "$(cat "$claude" "$opencode")"
check "and the check is satisfied" guard --check

echo 'not json' >"$claude"
check "a settings file that does not parse is left alone" \
  bash -c "$(declare -f guard); sandbox='$sandbox' ROOT='$ROOT' guard | grep -q 'not touching it'"
check "  as it was" test "$(cat "$claude")" = 'not json'

check "the real list names the SSH keys and the kubeconfigs" \
  bash -c "grep -qx '~/.ssh/\*\*' '$ROOT/default/agents/private-paths' && grep -qx '~/.kube/\*\*' '$ROOT/default/agents/private-paths'"

finish
