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
# in ~/.claude, which a clean install never had, and an empty prompt must not commit. It
# notes each call and keeps what it was sent, and fails as a spent limit does when told to.
cat >"$sandbox/bin/claude" <<STUB
#!/usr/bin/env bash
echo called >>"$sandbox/calls"
cat >"$sandbox/stdin"
[ -n "\$2" ] || exit 1
if [ -f "$sandbox/fail" ]; then
  echo "Claude AI usage limit reached" >&2
  exit 3
fi
cat "$sandbox/answer"
STUB
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
  fail "an answer in prose is not committed" "the script exited 0"
elif [[ $(git -C "$sandbox/repo" rev-parse HEAD) != "$before" ]]; then
  fail "an answer in prose is not committed" "a commit was made anyway"
else
  pass "an answer in prose is not committed"
fi

check "the staged diff reaches Claude directly, not by asking it to run git" grep -q '^+two' "$sandbox/stdin"

# Nothing staged used to be answered, after a call to Claude, with "stage less" -- the
# opposite of what was needed. It is caught first now, and Claude is not asked at all.
git -C "$sandbox/repo" reset -q
rm -f "$sandbox/calls"
out=$(cd "$sandbox/repo" && HOME="$sandbox" DESKTOP_PATH="$ROOT" PATH="$sandbox/bin:$PATH" bash "$GEN" 2>&1)
check "with nothing staged, Claude is not called" test ! -e "$sandbox/calls"
check "and the message says to stage, not to stage less" grep -q "Nothing is staged" <<<"$out"

# A spent limit or an expired login must say so, in Claude's words, and commit nothing.
stage three
touch "$sandbox/fail"
before=$(git -C "$sandbox/repo" rev-parse HEAD)
out=$(cd "$sandbox/repo" && HOME="$sandbox" DESKTOP_PATH="$ROOT" PATH="$sandbox/bin:$PATH" bash "$GEN" 2>&1)
check "when Claude fails, its own error is shown" grep -q "usage limit reached" <<<"$out"
check "and nothing is committed" test "$(git -C "$sandbox/repo" rev-parse HEAD)" = "$before"
rm -f "$sandbox/fail"

# A split is carried out: Claude answers with JSON naming each commit's files, and each
# becomes its own commit -- here the two changes the script itself was split into once.
split_repo() {
  git -C "$sandbox/repo" reset -q
  printf 'a\n' >"$sandbox/repo/script.sh"
  printf 'b\n' >"$sandbox/repo/keymaps.lua"
  git -C "$sandbox/repo" add script.sh keymaps.lua
}
plan() { # files of the first commit, as JSON
  printf '%s' '```json' $'\n' '{"commits": [{"files": '"$1"', "message": "fix(git-commit): say what went wrong\n\nThe reason.\n\nCo-Authored-By: Claude <noreply@anthropic.com>"}, {"files": ["keymaps.lua"], "message": "feat(nvim): compare two files"}]}' $'\n```\n' >"$sandbox/answer"
}
split_repo
plan '["script.sh"]'
before=$(git -C "$sandbox/repo" rev-parse HEAD)
generate
subjects=$(git -C "$sandbox/repo" log --format=%s "$before..HEAD" | tac | paste -sd'|' -)
check "a split becomes one commit per part, in order" test "$subjects" = "fix(git-commit): say what went wrong|feat(nvim): compare two files"
check "each part holds its own files" test "$(git -C "$sandbox/repo" show --name-only --format= HEAD~1)" = script.sh
check "and the trailers are stripped from each" lacks -i "co-authored" <<<"$(git -C "$sandbox/repo" log -2 --format=%B)"
check "nothing is left staged" git -C "$sandbox/repo" diff --cached --quiet

# A plan that loses a file, or a file with unstaged work too, commits nothing at all.
split_repo
printf 'a2\n' >"$sandbox/repo/script.sh"; git -C "$sandbox/repo" add script.sh
printf 'b2\n' >"$sandbox/repo/keymaps.lua"; git -C "$sandbox/repo" add keymaps.lua
plan '[]'
before=$(git -C "$sandbox/repo" rev-parse HEAD)
generate
check "a split that leaves a staged file out commits nothing" test "$(git -C "$sandbox/repo" rev-parse HEAD)" = "$before"
plan '["script.sh"]'
printf 'unstaged\n' >>"$sandbox/repo/script.sh"
generate
check "a split over a file with unstaged changes commits nothing" test "$(git -C "$sandbox/repo" rev-parse HEAD)" = "$before"
git -C "$sandbox/repo" checkout -q -- script.sh

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
