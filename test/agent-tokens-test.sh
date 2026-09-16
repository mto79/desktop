#!/usr/bin/env bash
# Tokens per day, per agent, counted from what each agent leaves on disk.
#
# Every check here is a way the counting has actually gone wrong, or nearly did:
#   - Claude Code copies a response's usage onto every content block it writes, so summing
#     lines counted each response 2.25 times on the machine this was written on;
#   - a resumed session repeats responses from the one it resumed, in another file;
#   - subagent transcripts live a directory deeper than projects/*/*.jsonl reaches;
#   - timestamps are UTC and days are local, and a fixed offset is wrong half the year;
#   - the bar reads this every fifteen seconds, so files are read incrementally, and an
#     incremental reader that double counts, or drops a half-written line, is worse than
#     none;
#   - codex logs a cumulative total after each turn, and summing those grows quadratically.
source "$(dirname "$0")/lib.sh"

require python3 || finish
require jq || finish

TOKENS="$ROOT/bin/desktop-agent-tokens"

sandbox=$(mktemp -d)
trap 'rm -rf "$sandbox"' EXIT

# A fixed zone with summer time, so the local-day checks mean the same thing anywhere.
export TZ=Europe/Amsterdam
export HOME="$sandbox/home"
export CLAUDE_CONFIG_DIR="$sandbox/claude"
export CODEX_HOME="$sandbox/codex"
export XDG_DATA_HOME="$sandbox/data"
export XDG_CACHE_HOME="$sandbox/cache"
projects="$CLAUDE_CONFIG_DIR/projects/-home-someone-repo"
mkdir -p "$projects" "$HOME"

# stamp <seconds ago>: an ISO UTC timestamp, the way the transcripts write them.
stamp() { date -u -d "@$(($(date +%s) - $1))" +%Y-%m-%dT%H:%M:%S.000Z; }

# claude_response <file> <message id> <seconds ago> <input> <cache write> <cache read> <output> [lines]
# Written as <lines> lines carrying identical usage, the way Claude Code writes a response
# with several content blocks.
claude_response() {
  local file="$1" id="$2" ago="$3" lines="${8:-1}" i
  for ((i = 0; i < lines; i++)); do
    printf '{"type":"assistant","timestamp":"%s","sessionId":"%s","message":{"id":"%s","usage":{"input_tokens":%s,"cache_creation_input_tokens":%s,"cache_read_input_tokens":%s,"output_tokens":%s}}}\n' \
      "$(stamp "$ago")" "$(basename "$file" .jsonl)" "$id" "$4" "$5" "$6" "$7" >>"$file"
  done
}

run() { python3 "$TOKENS" --json "$@"; }
claude() { run --agent claude "$@" | jq -r ".agents[0].$1"; }
today() { run --agent claude | jq -r ".agents[0].today.$1"; }

# --- the double count
claude_response "$projects/a.jsonl" msg_1 60 100 1000 50000 200 3
check "a response written as three content blocks is counted once" \
  test "$(today burned)" = 1300
check "cache reads are reported, but kept out of burned" test "$(today cache_read)" = 50000

# --- a resumed session repeating a response in another file
claude_response "$projects/b.jsonl" msg_1 60 100 1000 50000 200
claude_response "$projects/b.jsonl" msg_2 30 10 0 0 5
check "a response repeated in another transcript is still counted once" \
  test "$(today burned)" = 1315

# --- subagents, one level down
mkdir -p "$projects/b/subagents"
claude_response "$projects/b/subagents/agent-x.jsonl" msg_sub 20 1 0 0 1000
check "subagent transcripts are counted" test "$(today burned)" = 2316

# --- the five-hour window
claude_response "$projects/c.jsonl" msg_old 6*3600 7 0 0 7
check "a response outside the window is left out of it" \
  test "$(run --agent claude --window 5 | jq -r '.agents[0].window.burned')" = 2316
check "the window counts distinct sessions" \
  test "$(run --agent claude --window 5 | jq -r '.agents[0].window.sessions')" = 3

# --- incremental reading
before=$(today burned)
claude_response "$projects/a.jsonl" msg_1 60 100 1000 50000 200 2   # more blocks, same response
check "more lines of an already counted response change nothing" test "$(today burned)" = "$before"

# A line still being written: no newline yet. It must neither count nor be lost.
printf '{"type":"assistant","timestamp":"%s","sessionId":"a","message":{"id":"msg_half","usage":{"input_tokens":3,"cache_creation_input_tokens":0,"cache_read_input_tokens":0,"output_tokens":4' \
  "$(stamp 10)" >>"$projects/a.jsonl"
check "a half-written line is not counted" test "$(today burned)" = "$before"
printf '}}}\n' >>"$projects/a.jsonl"
check "and is counted once it is finished" test "$(today burned)" = $((before + 7))

# A file rewritten shorter -- not an append -- is read again from the top. Its own file,
# so what disappears with it is known exactly.
claude_response "$projects/e.jsonl" msg_e1 10 0 0 0 20
claude_response "$projects/e.jsonl" msg_e2 10 0 0 0 20
with_e=$(today burned)
: >"$projects/e.jsonl"
claude_response "$projects/e.jsonl" msg_e3 10 0 0 0 1
check "a rewritten file is read from the start, not from the old offset" \
  test "$(today burned)" = $((with_e - 40 + 1))

# --- local days, across midnight in summer time
midnight=$(date -d 'today 00:00' +%s)
since_midnight=$(($(date +%s) - midnight))
if ((since_midnight > 7200)); then
  # 30 minutes after local midnight is 22:30 UTC the day before, during CEST.
  claude_response "$projects/d.jsonl" msg_midnight $((since_midnight - 1800)) 0 0 0 1000000
  check "a response just after local midnight belongs to today, not to UTC's yesterday" \
    test "$(today output)" -ge 1000000
else
  pass "skipped the midnight check, too close to midnight to place a record safely"
fi

# --- a second caller with a different view must not spoil the first
settled=$(today burned)
run --agent claude --days 1 >/dev/null
run --days 7 >/dev/null
check "the bar's narrow query and the table's wide one share the cache without clashing" \
  test "$(today burned)" = "$settled"

# --- a sandbox never counts another machine's cache
other=$(mktemp -d)
check "records cached for other directories are not counted here" \
  test "$(CLAUDE_CONFIG_DIR="$other" run --agent claude | jq -r '.agents[0].today.burned')" = 0
rm -rf "$other"

# --- codex
sessions="$CODEX_HOME/sessions/2026/09/16"
mkdir -p "$sessions"
codex_turn() { # <seconds ago> <input> <cached> <output> <cumulative total>
  printf '{"timestamp":"%s","type":"event_msg","payload":{"type":"token_count","info":{"total_token_usage":{"total_tokens":%s},"last_token_usage":{"input_tokens":%s,"cached_input_tokens":%s,"output_tokens":%s}}}}\n' \
    "$(stamp "$1")" "$5" "$2" "$3" "$4" >>"$sessions/rollout-1.jsonl"
}
codex_turn 50 1000 800 50 1050
codex_turn 40 1000 800 50 1050   # logged twice: the cumulative total has not moved
codex_turn 30 2000 1500 100 3150
codex=$(run --agent codex | jq '.agents[0].today')
check "codex counts each turn, not the running total, and skips a repeated event" \
  test "$(jq -r .output <<<"$codex")" = 150
check "codex's cached input is split out of its input rather than counted twice" \
  test "$(jq -r '"\(.input) \(.cache_read)"' <<<"$codex")" = "700 2300"

# --- opencode
store="$XDG_DATA_HOME/opencode/storage/message/ses_1"
mkdir -p "$store"
created=$(($(date +%s) * 1000))
printf '{"id":"m1","role":"assistant","sessionID":"ses_1","tokens":{"input":100,"output":10,"reasoning":40,"cache":{"read":900,"write":5}},"time":{"created":%s}}' \
  "$created" >"$store/m1.json"
printf '{"id":"m0","role":"user","time":{"created":%s}}' "$created" >"$store/m0.json"
opencode=$(run --agent opencode | jq '.agents[0].today')
check "opencode's thinking tokens are counted as output" test "$(jq -r .output <<<"$opencode")" = 50
check "opencode's user messages are not counted" test "$(jq -r .burned <<<"$opencode")" = 155

# --- the panel reads the same numbers
window_out=$(run --agent claude --window 5 | jq -r '.agents[0].window.output')
expected=$(python3 -c "
v = $window_out
print(next((f'{v / l:.1f}{s}' for l, s in ((10**9, 'G'), (10**6, 'M'), (10**3, 'k')) if v >= l), str(v)))")
report=$(XDG_RUNTIME_DIR="$sandbox/run" python3 "$ROOT/bin/desktop-status-claude" --report)
check "the panel's token row is the deduplicated count" \
  test "$(jq -r .tokens.out <<<"$report")" = "$expected"

check "the table renders" grep -q "burned" <<<"$(python3 "$TOKENS")"

finish
