#!/usr/bin/env bash
# Voice commands: what was heard becomes one of a fixed list of things, or nothing.
#
# Every command the list could run is a stub that writes down what it was asked, so what
# is checked is the mapping -- and, more to the point, what a sentence must never turn
# into: a restart, or a prompt sent to an agent without being read first.
source "$(dirname "$0")/lib.sh"

require jq || finish

VOICE="$ROOT/bin/desktop-voice"
sandbox=$(mktemp -d)
trap 'rm -rf "$sandbox"' EXIT
stubs="$sandbox/stubs"
mkdir -p "$stubs"

for cmd in desktop-shell desktop-say desktop-power wpctl tmux desktop-menu-agents desktop-cmd-screenshot uwsm desktop-brief systemctl; do
  printf '#!/usr/bin/env bash\nprintf "%%s\\n" "%s $*" >>"%s/calls"\n' "$cmd" "$sandbox" >"$stubs/$cmd"
done
cat >"$stubs/hyprctl" <<STUB
#!/usr/bin/env bash
if [[ \$1 == clients ]]; then
  echo '[{"address":"0xaa","class":"org.mozilla.firefox","title":"iDRAC9 - Mozilla Firefox","mapped":true,"focusHistoryID":2},
         {"address":"0xbb","class":"com.mitchellh.ghostty","title":"tmux","mapped":true,"focusHistoryID":1}]'
else
  printf '%s\n' "hyprctl \$*" >>"$sandbox/calls"
fi
STUB
cat >"$stubs/desktop-agent-sessions" <<'STUB'
#!/usr/bin/env bash
echo '{"sessions":[{"project":"desktop","pane":"%7","socket":"/s","target":"ai-desktop-1-claude:1.1"},
                   {"project":"idrac-security","pane":"%9","socket":"/s","target":"ai-idrac-security-2-claude:1.1"}]}'
STUB
# setsid -f detaches; here the thing it would start is simply run, so it is written down.
printf '#!/usr/bin/env bash\n[[ $1 == -f ]] && shift\nexec "$@"\n' >"$stubs/setsid"
chmod +x "$stubs"/*

# It stands in for Ollama: answers with whatever the test put in $sandbox/model, and
# writes down what it was asked.
cat >"$stubs/curl" <<STUB
#!/usr/bin/env bash
for a in "\$@"; do [[ \$a == *'"messages"'* ]] && printf '%s\n' "\$a" >"$sandbox/asked"; done
[[ " \$* " == *"/api/chat"* ]] || exit 0
[[ -s "$sandbox/model" ]] || exit 22
jq -cn --rawfile c "$sandbox/model" '{message: {content: \$c}}'
STUB
chmod +x "$stubs/curl"

say() { : >"$sandbox/calls"; PATH="$stubs:$PATH" XDG_RUNTIME_DIR="$sandbox/run" DESKTOP_VOICE_LEARN=off DESKTOP_VOICE_ALIASES="$sandbox/aliases" XDG_STATE_HOME="$sandbox/state" DESKTOP_VOICE_ALIASES="$sandbox/aliases" DESKTOP_VOICE_CONF="$sandbox/none.conf" bash "$VOICE" run "$1" >/dev/null 2>&1; }
did() { grep -qxF -- "$1" "$sandbox/calls"; }
shown() { jq -r .text "$sandbox/run/desktop/say/now" 2>/dev/null; }

# --- as the recogniser really hears them
say "Go to Workspace 3."
check "a workspace by its number" did "hyprctl dispatch hl.dsp.focus({ workspace = 3 })"
say "workspace three"
check "or by the word for it" did "hyprctl dispatch hl.dsp.focus({ workspace = 3 })"
say "Dashboard."
check "the dashboard is workspace 6" did "hyprctl dispatch hl.dsp.focus({ workspace = 6 })"
say "Dashboard health"
check "a tab of the dashboard by its subject" did "desktop-shell shell dashboardTab health"
say "show domotics"
check "domotics is the house" did "desktop-shell shell dashboardTab home"
say "Show the news."
check "the news" did "desktop-shell shell dashboardTab news"
say "show the clusters"
check "or by the word you would use for it" did "desktop-shell shell dashboardTab infra"
check "and the clusters are what that tab then shows" did "desktop-shell shell infraSection clusters"
say "Which network am I on?"
check "the network is a heading of the infrastructure tab" did "desktop-shell shell infraSection network"
say "where am i"
check "asked for the way you would ask" did "desktop-shell shell infraSection network"
say "Show the VPN routes."
check "the VPN's routes open its box in the network picture" did "desktop-shell shell networkDetails vpn"
say "what goes through the vpn"
check "  asked the way you would ask" did "desktop-shell shell networkDetails vpn"
say "Scan the network."
check "a network scan is started by voice" did "desktop-shell shell scanNetwork quiet"
check "  and never as a sweep: that stays a button press" lacks -q 'scanNetwork sweep' "$sandbox/calls"
say "who else is on my network"
check "  asked the way you would ask" did "desktop-shell shell scanNetwork quiet"
say "What Bluetooth devices are near?"
check "listening for Bluetooth by voice" did "desktop-shell shell scanBluetooth"
check "  on its own heading" did "desktop-shell shell infraSection bluetooth"
say "Lock the screen."
check "lock locks" did "desktop-power lock"
say "Show the overview"
check "the overview" did "desktop-shell shell toggleOverview"
say "Clear all notifications."
check "clearing notifications" did "desktop-shell shell clearNotifications"
say "notifications"
check "showing them is a different thing from clearing them" did "desktop-shell shell togglePanel notifications"
say "What's waiting?"
check "the brief is said out loud" did "desktop-brief --say"
say "hush"
check "hush hushes" did "desktop-say --hush"
say "louder"
check "the volume" did "wpctl set-volume -l 1.0 @DEFAULT_AUDIO_SINK@ 10%+"

# The cluster's name arrives in pieces, and "k9s" as almost anything.
say "Nines on OCP 204."
check "k9s on a cluster, as it is actually heard" did "uwsm app -- ghostty -e ocl -k ocp204"
say "K nines on O C P two oh four"
check "and spelled out" did "uwsm app -- ghostty -e ocl -k ocp204"
say "argo on ocp 302"
check "Argo CD on a cluster" did "uwsm app -- ghostty -e ocl -a ocp302"
say "shell on ocp203"
check "a shell on a cluster" did "uwsm app -- ghostty -e ocl ocp203"

say "go to firefox"
check "a window by a word in its name" did 'hyprctl dispatch hl.dsp.focus({ window = "address:0xaa" })'
say "open spreadsheet"
check "a window that is not there is said to be not there" grep -q 'No window called' <<<"$(shown)"

# --- what a sentence must never become
for sentence in "reboot" "shut down the computer" "Power off." "log out" "suspend" "restart the machine"; do
  say "$sentence"
  check "\"$sentence\" does nothing from here" test ! -s "$sandbox/calls"
done
check "and says where that is done instead" grep -q 'Super + Escape' <<<"$(shown)"

say "delete everything in my home directory"
check "a sentence that is not on the list runs nothing at all" lacks -E 'dispatch|ghostty|send-keys|togglePanel|desktop-(lock|say|worktree|cmd)' "$sandbox/calls"
say 'workspace 3; rm -rf ~'
check "nor does one with a command tucked in after a real one" lacks 'rm' "$sandbox/calls"
check "there is no way from what was heard to a shell" lacks -E 'eval|bash -c|sh -c' "$VOICE"

# --- to an agent
say "Tell desktop to run the tests."
check "what is said to an agent is typed into its prompt" did "tmux -S /s send-keys -t %7 -l -- run the tests."
check "and not sent: Enter is yours" lacks -E 'send-keys.*(Enter|C-m)' "$sandbox/calls"
check "you are taken to it, to read what was heard" did "desktop-menu-agents --jump ai-desktop-1-claude:1.1 /s"
say "Ask idrac security to renew the certificate, then tell me"
check "a project of two words, and a message with a 'to' of its own" \
  did "tmux -S /s send-keys -t %9 -l -- renew the certificate, then tell me"
say "tell desktop to lock the screen"
check "what follows 'tell' is a message, never a command of its own" lacks 'desktop-power' "$sandbox/calls"
say "tell nobody to do something"
check "an agent that is not there gets nothing" lacks 'send-keys' "$sandbox/calls"

# --- one press: knowing when somebody has stopped talking
ENDPOINT="$ROOT/bin/desktop-voice-endpoint"
# Sound made here: a microphone's opening click, a quiet room, and a voice as a tone.
sound() { # <seconds of room> <seconds of voice> <seconds of room> [level of the voice]
  python3 - "$@" <<'PY'
import array, math, random, sys
rate = 16000
before, voice, after = (float(a) for a in sys.argv[1:4])
loud = int(sys.argv[4]) if len(sys.argv) > 4 else 6000
random.seed(1)
out = array.array("h")
out.extend(int(random.uniform(-1, 1) * 2500) for _ in range(int(rate * 0.1)))        # the click
out.extend(int(random.uniform(-1, 1) * 40) for _ in range(int(rate * before)))       # the room
out.extend(int(math.sin(i / 9.0) * loud) for i in range(int(rate * voice)))          # a voice
out.extend(int(random.uniform(-1, 1) * 40) for _ in range(int(rate * after)))        # the room
sys.stdout.buffer.write(out.tobytes())
PY
}
heard() { sound "$@" 2>/dev/null | python3 "$ENDPOINT" "${ENDPOINT_ARGS[@]}"; echo "${PIPESTATUS[1]}"; }
ENDPOINT_ARGS=()
check "speech followed by silence is the end of a command" test "$(heard 0.5 1.2 2.0)" = 0
check "a room where nobody speaks is not a command" test "$(heard 5.0 0 0)" = 1
# The click a microphone opens with was taken for the room, and set the bar above any voice.
check "the microphone's opening click is not taken for the room" test "$(heard 0.3 1.0 2.0 1500)" = 0
check "somebody who starts talking at once is still heard" test "$(heard 0.0 1.5 2.0)" = 0
ENDPOINT_ARGS=(--max 2)
check "talking past the limit ends there, with what was said" test "$(heard 0.2 6.0 0)" = 0
ENDPOINT_ARGS=()
check "a cough is not speech" test "$(heard 1.0 0.08 4.5)" = 1
# pw-record ignores SIGPIPE: piped into the listener it outlived it, and nothing ended.
check "the recorder is stopped, not left to notice" \
  test -n "$(sed -n '/^watching()/,/^}/p' "$VOICE" | grep 'kill "$recorder"')"
check "and is not piped into the listener" lacks -E 'pw-record .*\| *desktop-voice-endpoint' "$VOICE"
check "the key need only be pressed once" grep -q 'watch_for_the_end "$mark"' "$VOICE"
check "nobody speaking cancels, and does not complain" \
  test -n "$(sed -n '/^watching()/,/^}/p' "$VOICE" | grep 'if \[\[ $ended == 0 \]\]; then finish_recording; else cancel; fi')"

# --- more to say
cat >"$stubs/desktop-agent-sessions" <<'STUB'
#!/usr/bin/env bash
echo '{"sessions":[{"project":"desktop","state":"working","since":10,"pane":"%7","socket":"/s","target":"ai-desktop-1-claude:1.1"},
                   {"project":"idrac-security","state":"waiting","since":50,"pane":"%9","socket":"/s","target":"ai-idrac-security-2-claude:1.1"}]}'
STUB
cat >"$stubs/tmux" <<STUB
#!/usr/bin/env bash
printf '%s\n' "tmux \$*" >>"$sandbox/calls"
case " \$* " in
*"list-panes"*) echo "desktop-1" ;;
*"list-clients"*) echo "ai-desktop-1-claude" ;;
*"#{pane_id}"*) echo "%3" ;;
*"#{pane_current_path}"*) echo "$sandbox" ;;
*"#{client_name}"*) echo "/dev/pts/1" ;;
esac
STUB
printf '#!/usr/bin/env bash\nprintf "%%s\\n" "desktop-worktree $*" >>"%s/calls"\n' "$sandbox" >"$stubs/desktop-worktree"
cat >"$stubs/desktop-dash" <<'STUB'
#!/usr/bin/env bash
case "$1" in
news) echo '{"feeds":[{"category":"tech","name":"Tweakers","ok":true,"items":[{"title":"Een"},{"title":"Twee"},{"title":"Drie"},{"title":"Vier"}]},{"category":"world","name":"NOS","ok":true,"items":[{"title":"Wereld"}]}]}' ;;
infra) echo '{"signed_in":2,"trouble":1,"clusters":[{"name":"ocp204","state":"degraded","nodes":12,"ready":11},{"name":"ocp202","state":"healthy","nodes":9,"ready":9}]}' ;;
watch) echo '{"items":[{"name":"kubie","state":"behind","newest":"0.28.0"},{"name":"k9s","state":"current","newest":"0.51.0"}]}' ;;
esac
STUB
chmod +x "$stubs"/*
said_aloud() { grep -q -- "$1" "$sandbox/calls"; }

say "tell it to run the tests"
check "'it' is the agent in the window you are in" did "tmux -S /s send-keys -t %7 -l -- run the tests"
say "go to the waiting agent"
check "the agent that is waiting can be gone to" did "desktop-menu-agents --jump ai-idrac-security-2-claude:1.1 /s"
say "start a task called fix the runner"
check "a task can be started, where you are" did "desktop-worktree new --tab %3 fix the runner"
say "finish the task"
check "finishing a task opens the question, and answers nothing itself" did "desktop-worktree finish %3 /dev/pts/1"
check "nothing here says yes to it" lacks -E 'done( --ask)?$|<<<.?y' "$sandbox/calls"
say "world news"
check "a heading of the news" did "desktop-shell shell newsSection world"
say "what's new on tweakers"
check "three headlines are read, from the site asked for" said_aloud "desktop-say Tweakers. Een. Twee. Drie."
say "read the world headlines"
check "or from a heading" said_aloud "desktop-say NOS. Wereld."
say "cluster status"
check "which clusters are in trouble is said" said_aloud "desktop-say In trouble: ocp204, 1 nodes not ready"
say "what is behind"
check "and what has a newer version" said_aloud "desktop-say Newer versions: kubie 0.28.0"

say "workspace 4"
say "again"
check "'again' does the last thing once more" did "hyprctl dispatch hl.dsp.focus({ workspace = 4 })"
say "tell desktop to run the tests"
say "again"
check "but never sends a message to an agent twice" lacks 'send-keys' "$sandbox/calls"

# --- a model for what the list does not know
model_says() { printf '%s' "$1" >"$sandbox/model"; rm -f "$sandbox/asked"; }

model_says '{"action":"workspace","arg":"3"}'
say "could you bring up the third one"
check "a sentence the list does not know is put to the model" did "hyprctl dispatch hl.dsp.focus({ workspace = 3 })"
check "which is told what is in front of you" grep -q 'Focused window' "$sandbox/asked"
check "and may only answer from a fixed set" grep -q '"enum"' "$sandbox/asked"
rm -f "$sandbox/asked"
say "workspace 4"
check "what the list knows never goes to the model" test ! -e "$sandbox/asked"

# What the model says is not done: it is turned into a sentence the list knows.
model_says '{"action":"k9s","arg":"ocp204; rm -rf ~"}'
say "do the cluster thing"
check "an argument with a command in it comes to nothing" lacks 'ghostty' "$sandbox/calls"
model_says '{"action":"focus","arg":"$(reboot)"}'
say "bring that thing forward"
check "and cannot reach a shell" lacks -E '\$\(|reboot' "$sandbox/calls"
model_says '{"action":"reboot","arg":""}'
say "make the machine start over"
check "an action that is not on the list is nothing" lacks -E 'dispatch|ghostty|send-keys|togglePanel|desktop-(lock|say|worktree|cmd)' "$sandbox/calls"
model_says '{"action":"focus","arg":"shutdown"}'
say "bring that thing forward"
check "what is refused when said is refused when the model says it" lacks 'focuswindow' "$sandbox/calls"
model_says 'not json at all'
say "mumble mumble"
check "an answer that makes no sense is nothing" lacks -E 'dispatch|ghostty|send-keys|togglePanel|desktop-(lock|say|worktree|cmd)' "$sandbox/calls"
rm -f "$sandbox/model"
say "mumble mumble"
check "and so is no answer: Ollama not running" lacks -E 'dispatch|ghostty|send-keys|togglePanel|desktop-(lock|say|worktree|cmd)' "$sandbox/calls"
# A message to an agent must be your words, not a paraphrase of them.
model_says '{"action":"lock","arg":""}'
say "tell desktop to lock the door"
check "a message to an agent never goes to the model" test ! -e "$sandbox/asked"
check "the model cannot empty the notification centre" lacks 'clear' <(sed -n '/^understand()/,/^}/p' "$VOICE" | grep -v '^ *#')
DESKTOP_VOICE_MODEL=off say "could you bring up the third one"
check "it can be switched off" test ! -e "$sandbox/asked"
check "a clean install fetches the model where there is an Ollama" grep -q 'packaging/voice.sh' "$ROOT/install/packaging/all.sh"

# --- a better model elsewhere, when it can be reached
cat >"$stubs/curl" <<STUB
#!/usr/bin/env bash
printf '%s\n' "curl \$*" >>"$sandbox/curls"
case " \$* " in
*"/chat/completions"*) [[ -s "$sandbox/remote" ]] || exit 6; jq -cn --rawfile c "$sandbox/remote" '{choices: [{message: {content: \$c}}]}' ;;
*"/api/chat"*) [[ -s "$sandbox/model" ]] || exit 22; jq -cn --rawfile c "$sandbox/model" '{message: {content: \$c}}' ;;
esac
STUB
printf 'remote_url=http://localhost:9/\nremote_model=Big/Model # the large one\nremote_key_file=%s/key\n' "$sandbox" >"$sandbox/voice.conf"
printf 'sekrit-key\n' >"$sandbox/key"
far() { : >"$sandbox/calls"; : >"$sandbox/curls"; PATH="$stubs:$PATH" XDG_RUNTIME_DIR="$sandbox/run" DESKTOP_VOICE_LEARN=off DESKTOP_VOICE_ALIASES="$sandbox/aliases" XDG_STATE_HOME="$sandbox/state" DESKTOP_VOICE_CONF="$sandbox/voice.conf" bash "$VOICE" run "$1" >/dev/null 2>&1; }
which_model() { jq -r '"\(.name) \(.where)"' "$sandbox/run/desktop/voice/model" 2>/dev/null; }

printf '<think>hm</think> {"action":"workspace","arg":"5"}' >"$sandbox/remote"
model_says '{"action":"workspace","arg":"9"}'
far "could you bring up the fifth one"
check "the model elsewhere is asked first when it is in reach" did "hyprctl dispatch hl.dsp.focus({ workspace = 5 })"
check "and it is written down that the sentence left this machine" test "$(which_model)" = "Big/Model remote"
check "its key is never on a command line" lacks 'sekrit-key' "$sandbox/curls"
rm -f "$sandbox/remote"
far "could you bring up the fifth one"
check "when it does not answer, the one on this machine is asked" did "hyprctl dispatch hl.dsp.focus({ workspace = 9 })"
check "and that is what is written down" test "$(which_model)" = "qwen2.5:3b local"
sed -i 's|^remote_url=.*|remote_url=https://nowhere.invalid|' "$sandbox/voice.conf"
printf '{"action":"workspace","arg":"5"}' >"$sandbox/remote"
far "could you bring up the fifth one"
check "a name that does not resolve -- the VPN is down -- is not even tried" lacks 'chat/completions' "$sandbox/curls"
# Where it is and what its key is are this machine's business, not the repository's.
check "no server of anybody's is written into the command" lacks -E 'https?://[a-z0-9.-]+\.(net|nl|com)' <(grep -v 'api\.anthropic\.com' "$ROOT/bin/desktop-voice")
check "the cards say which model, and whether it is here" grep -q 'Speech.modelLine' "$ROOT/shell/Voice/Voice.qml" "$ROOT/shell/Dashboard/Dashboard.qml"

# --- the cloud: the cleverest model, and the furthest away
cat >"$stubs/curl" <<STUB
#!/usr/bin/env bash
printf '%s\n' "curl \$*" >>"$sandbox/curls"
case " \$* " in
*"/v1/messages"*) cat >"$sandbox/body"; [[ -s "$sandbox/cloud" ]] || exit 22; cat "$sandbox/cloud" ;;
*"/chat/completions"*) cat >/dev/null; [[ -s "$sandbox/remote" ]] || exit 6; jq -cn --rawfile c "$sandbox/remote" '{choices: [{message: {content: \$c}}]}' ;;
*"/api/chat"*) [[ -s "$sandbox/model" ]] || exit 22; jq -cn --rawfile c "$sandbox/model" '{message: {content: \$c}}' ;;
esac
STUB
printf '#!/usr/bin/env bash\n[[ -e "%s/haskey" ]] && echo sk-ant-sekrit\n' "$sandbox" >"$stubs/secret-tool"
chmod +x "$stubs/secret-tool"
cloud() { : >"$sandbox/calls"; : >"$sandbox/curls"; rm -f "$sandbox/body"; PATH="$stubs:$PATH" XDG_RUNTIME_DIR="$sandbox/run" DESKTOP_VOICE_LEARN=off DESKTOP_VOICE_ALIASES="$sandbox/aliases" XDG_STATE_HOME="$sandbox/state" DESKTOP_VOICE_ALIASES="$sandbox/aliases" DESKTOP_VOICE_CONF="$sandbox/none.conf" bash "$VOICE" "${@:2}" run "$1" >/dev/null 2>&1; }
set_mode() { PATH="$stubs:$PATH" XDG_RUNTIME_DIR="$sandbox/run" XDG_STATE_HOME="$sandbox/state" bash "$VOICE" mode "$1" >/dev/null 2>&1; }
haiku_says() { jq -cn --arg t "$1" --arg stop "${2:-end_turn}" '{stop_reason: $stop, content: [{type: "text", text: $t}]}' >"$sandbox/cloud"; }

haiku_says '{"action":"workspace","arg":"7"}'
model_says '{"action":"workspace","arg":"9"}'
touch "$sandbox/haskey"
cloud "could you bring up the seventh one"
check "nothing goes to the cloud unless you chose it" did "hyprctl dispatch hl.dsp.focus({ workspace = 9 })"
set_mode cloud
cloud "could you bring up the seventh one"
check "in cloud mode a sentence the list does not know goes to Haiku" did "hyprctl dispatch hl.dsp.focus({ workspace = 7 })"
check "which is written down as having left" test "$(which_model)" = "claude-haiku-5-5 cloud"
check "the sentence goes alone: no window, no agents, no last command" lacks -E 'Focused window|Coding agents|Last command' "$sandbox/body"
check "and is held to the same fixed set" test "$(jq -r '.output_config.format.schema.properties.action.enum | index("workspace") != null' "$sandbox/body")" = true
check "the key is never on a command line" lacks 'sk-ant-sekrit' "$sandbox/curls"
check "every sentence sent is kept in a log" grep -q 'could you bring up the seventh one' "$sandbox/state/desktop/voice/sent.log"
cloud "workspace 4"
check "what the list knows still never leaves" test ! -e "$sandbox/body"
cloud "do the usual on o c p two oh four"
check "a sentence naming a cluster stays on this machine" test ! -e "$sandbox/body"
cloud "how is idrac security getting on"
check "and so does one naming a project an agent is working on" test ! -e "$sandbox/body"
cloud "tell desktop to lock the door"
check "a message to an agent never goes anywhere" test ! -e "$sandbox/body"
haiku_says '{"action":"workspace","arg":"7"}' refusal
cloud "could you bring up the seventh one"
check "a refusal is no answer, and the local model is asked" did "hyprctl dispatch hl.dsp.focus({ workspace = 9 })"
haiku_says '{"action":"lock; reboot","arg":""}'
model_says 'x'
cloud "do the thing"
check "an action the cloud invents is nothing" lacks -E 'dispatch|desktop-lock|reboot' "$sandbox/calls"
rm -f "$sandbox/haskey"
haiku_says '{"action":"workspace","arg":"7"}'
model_says '{"action":"workspace","arg":"9"}'
cloud "could you bring up the seventh one"
check "without a key in the keyring nothing is sent" test ! -e "$sandbox/body"
touch "$sandbox/haskey"; set_mode local
printf '{"action":"workspace","arg":"5"}' >"$sandbox/remote"
: >"$sandbox/calls"; : >"$sandbox/curls"; PATH="$stubs:$PATH" XDG_RUNTIME_DIR="$sandbox/run" DESKTOP_VOICE_LEARN=off DESKTOP_VOICE_ALIASES="$sandbox/aliases" XDG_STATE_HOME="$sandbox/state" DESKTOP_VOICE_CONF="$sandbox/voice.conf" bash "$VOICE" run "could you bring up the seventh one" >/dev/null 2>&1
check "local mode asks nobody else at all" lacks -E 'v1/messages|chat/completions' "$sandbox/curls"
check "the key is kept in the keyring, not in a file" grep -q 'secret-tool lookup service desktop-voice account anthropic' "$VOICE"

# --- what it learns, and what you tell it
set_mode local
learnt() { PATH="$stubs:$PATH" XDG_RUNTIME_DIR="$sandbox/run" XDG_STATE_HOME="$sandbox/state" DESKTOP_VOICE_ALIASES="$sandbox/aliases" DESKTOP_VOICE_CONF="$sandbox/none.conf" bash "$VOICE" "$@" 2>/dev/null; }
teachable() { : >"$sandbox/calls"; : >"$sandbox/curls"; learnt run "$1" >/dev/null; }
model_says '{"action":"workspace","arg":"8"}'
teachable "let me see number eight"
check "a sentence a model made sense of is done" did "hyprctl dispatch hl.dsp.focus({ workspace = 8 })"
check "and kept, with what it meant and who said so" test "$(learnt learned --json | jq -r '.learned[0] | "\(.phrase)|\(.command)|\(.by)"')" = "let me see number 8|workspace 8|qwen2.5:3b"
rm -f "$sandbox/model"
teachable "let me see number eight"
check "said again it is known, with no model there at all" did "hyprctl dispatch hl.dsp.focus({ workspace = 8 })"
check "and nobody is asked" lacks -E 'api/chat|v1/messages|chat/completions' "$sandbox/curls"
model_says '{"action":"none","arg":""}'
teachable "order me a pizza"
check "what nobody could make out is listed too" test "$(learnt learned --json | jq -r '.missed[0].phrase')" = "order me a pizza"
check "and is not learned" test "$(learnt learned --json | jq '.learned | length')" = 1
learnt forget "let me see number eight"
check "a thing learned wrongly can be thrown out" test "$(learnt learned --json | jq '.learned | length')" = 0
learnt teach "Coffee time!" "lock the screen"
teachable "coffee time"
check "you can say what a phrase means yourself" did "desktop-power lock"
check "which is kept in a file of your own" grep -qx 'coffee time = lock the screen' "$sandbox/aliases"
learnt teach "pizza" "reboot"
teachable "pizza"
check "a phrase cannot be taught to do what is refused" lacks -E 'reboot|systemctl' "$sandbox/calls"
learnt teach "pizza" 'workspace 3; rm -rf ~'
teachable "pizza"
check "nor to reach a shell" lacks -E 'rm -rf' "$sandbox/calls"
learnt forget "coffee time"
check "and yours can be dropped the same way" lacks 'coffee time' "$sandbox/aliases"
check "the dashboard lists what was learned, with a way to drop each" \
  test "$(grep -c 'onChosen: Speech.forget(modelData.phrase)' "$ROOT/shell/Dashboard/AiPage.qml")" = 3
check "the three ways are buttons, on the dashboard and in the AI panel" \
  test "$(grep -l 'options: Speech.modeOptions' "$ROOT/shell/Dashboard/Dashboard.qml" "$ROOT/shell/Bar/panels/AiPanel.qml" | wc -l)" = 2
# desktop-voice state is asked for every minute and must write nothing, or it would
# wake the shell that asked, for ever.
before=$(ls -la --time-style=full-iso "$sandbox/run/desktop/voice/" | md5sum)
learnt state >/dev/null
check "asking for the state changes nothing" test "$(ls -la --time-style=full-iso "$sandbox/run/desktop/voice/" | md5sum)" = "$before"

# --- wired in
check "SUPER + C listens" \
  grep -qx 'bindd = SUPER, C, Voice command, exec, desktop-voice toggle' "$ROOT/default/hypr/bindings/utilities.conf"
check "in the Lua bindings as well" grep -q 'SUPER + C.*desktop-voice toggle' "$ROOT/default/hypr/bindings/utilities.lua"
check "the microphone cannot be left open" grep -q 'desktop-voice-endpoint --max "$MAX_SECONDS" <&3' "$VOICE"
# Transcribing a recording from the command line loads the model every time; the daemon
# has it loaded. That was the difference between four seconds and one.
check "it listens through the dictation daemon, which has the model loaded" \
  grep -q 'voxtype record start --file="$RUN_DIR/heard.txt"' "$VOICE"
check "and what the daemon wrote is removed once it has been understood" grep -q 'rm -f "$RUN_DIR/heard.txt"' "$VOICE"
check "what was recorded is removed once it has been understood" grep -q 'rm -f "$RUN_DIR/heard.wav"' "$VOICE"
check "the list of what it understands is printed" test "$(bash "$VOICE" list | wc -l)" -ge 12

# The buttons showed the way that was chosen as the one in use: with the VPN down, "VPN"
# stayed lit while every sentence went to the local model.
check "the lit button is the model in use, not the one asked for" \
  test "$(grep -l 'chosen: Speech.modeInUse' "$ROOT"/shell/Bar/panels/AiPanel.qml "$ROOT"/shell/Dashboard/AiPage.qml "$ROOT"/shell/Dashboard/Dashboard.qml | wc -l)" = 3
check "and nowhere the other way round" lacks -rE 'chosen: Speech\.mode$' "$ROOT/shell"

# In local mode the VPN's model was reported as unreachable, so its button was dimmed
# with the VPN up -- and looked like something that could not be chosen.
check "whether the VPN model is there does not depend on the mode" \
  grep -q 'argjson reachable "$(remote_there ' "$ROOT/bin/desktop-voice"

finish
