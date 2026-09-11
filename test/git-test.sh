#!/usr/bin/env bash
# desktop-git-commit commits what Claude answers, into a repository made for the test.
#
# Two things reached real commits: Claude Code's Co-Authored-By trailer on every message,
# and, when the staged changes were unrelated, Claude's whole suggested split -- prose,
# bold headings, fenced messages -- committed as one message with a sentence for a title.
source "$(dirname "$0")/lib.sh"

require git || finish

GEN="$ROOT/bin/desktop-git-commit"

sandbox=$(mktemp -d)
trap 'rm -rf "$sandbox"' EXIT
mkdir -p "$sandbox/bin" "$sandbox/repo"

# claude prints whatever $sandbox/answer holds, so each case sets the answer it needs. It
# answers nothing when handed no prompt: the prompt used to be read from a hand-placed file
# in ~/.claude, which a clean install never had, and an empty prompt must not commit.
printf '#!/usr/bin/env bash\n[ -n "$2" ] || exit 1\ncat "%s/answer"\n' "$sandbox" >"$sandbox/bin/claude"
chmod +x "$sandbox/bin/claude"

git -C "$sandbox/repo" init -q
git -C "$sandbox/repo" config user.name test
git -C "$sandbox/repo" config user.email test@example.com
git -C "$sandbox/repo" config commit.gpgsign false

generate() {
  (cd "$sandbox/repo" && HOME="$sandbox" DESKTOP_PATH="$ROOT" PATH="$sandbox/bin:$PATH" bash "$GEN") >/dev/null 2>&1
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

# lazygit names these commands in a config that is copied, not sourced, so a rename in bin/
# that misses config/lazygit/config.yml leaves a key that fails only when pressed.
missing=()
for cmd in $(grep -oP "command: '\K[^ ']+" "$ROOT/config/lazygit/config.yml"); do
  [[ -x $ROOT/bin/$cmd ]] || missing+=("$cmd")
done
if ((${#missing[@]} == 0)); then
  pass "every lazygit custom command exists in bin/"
else
  fail "every lazygit custom command exists in bin/" "not in bin/: ${missing[*]}"
fi

# bin/ is on PATH in place. The lazygit scripts were also copied into ~/.local/bin, which
# fish puts first, so an edit here did nothing in a terminal until it was copied again.
if grep -q 'bin/.*local/bin' "$ROOT/install/config/config.sh"; then
  fail "no install step copies bin/ scripts elsewhere" "install/config/config.sh still does"
else
  pass "no install step copies bin/ scripts elsewhere"
fi
finish
