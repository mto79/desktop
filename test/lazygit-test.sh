#!/usr/bin/env bash
# lazygit-gen-commit commits what Claude answers, into a repository made for the test.
#
# Two things reached real commits: Claude Code's Co-Authored-By trailer on every message,
# and, when the staged changes were unrelated, Claude's whole suggested split -- prose,
# bold headings, fenced messages -- committed as one message with a sentence for a title.
source "$(dirname "$0")/lib.sh"

require git || finish

GEN="$ROOT/bin/lazygit-gen-commit"

sandbox=$(mktemp -d)
trap 'rm -rf "$sandbox"' EXIT
mkdir -p "$sandbox/bin" "$sandbox/.claude/commands" "$sandbox/repo"
touch "$sandbox/.claude/commands/gen-commit-msg.md"

# claude prints whatever $sandbox/answer holds, so each case sets the answer it needs.
printf '#!/usr/bin/env bash\ncat "%s/answer"\n' "$sandbox" >"$sandbox/bin/claude"
chmod +x "$sandbox/bin/claude"

git -C "$sandbox/repo" init -q
git -C "$sandbox/repo" config user.name test
git -C "$sandbox/repo" config user.email test@example.com
git -C "$sandbox/repo" config commit.gpgsign false

generate() {
  (cd "$sandbox/repo" && HOME="$sandbox" PATH="$sandbox/bin:$PATH" bash "$GEN") >/dev/null 2>&1
}

stage() {
  printf '%s\n' "$1" >>"$sandbox/repo/file"
  git -C "$sandbox/repo" add file
}

stage one
printf '%s\n' '```' 'fix(shell): hide the settings button' '' \
  'Chromium adds it to every web notification.' '' '' \
  'Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>' \
  'Claude-Session: https://claude.ai/code/session_x' '' \
  '🤖 Generated with [Claude Code](https://claude.com/claude-code)' '```' >"$sandbox/answer"
generate
msg=$(git -C "$sandbox/repo" log -1 --format=%B 2>/dev/null)
expected=$'fix(shell): hide the settings button\n\nChromium adds it to every web notification.'
if [[ $msg == "$expected" ]]; then
  pass "the agent's trailers and fences are stripped from the commit"
else
  fail "the agent's trailers and fences are stripped from the commit" "got: ${msg//$'\n'/\\n}"
fi

stage two
printf '%s\n' "The staged work is two unrelated changes; I'd split it:" '' \
  '**1. Shell**' '' '```' 'fix(shell): one thing' '```' >"$sandbox/answer"
before=$(git -C "$sandbox/repo" rev-parse HEAD)
if generate; then
  fail "a suggested split is not committed" "the script exited 0"
elif [[ $(git -C "$sandbox/repo" rev-parse HEAD) != "$before" ]]; then
  fail "a suggested split is not committed" "a commit was made anyway"
else
  pass "a suggested split is not committed"
fi
finish
