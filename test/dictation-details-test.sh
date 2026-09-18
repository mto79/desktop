#!/usr/bin/env bash
# desktop-dictation-details, with voxtype's journal, config and service faked.
#
# The journal is read for two things that each went wrong once: the transcript is taken
# from the "Transcribed:" line, not the "completed" line voxtype cuts at fifty characters
# -- copying back a transcript that ends in "..." is worse than not offering it -- and
# each entry keeps the length spoken, which is how the panel tells a dictation that ran
# into the recording limit.
source "$(dirname "$0")/lib.sh"

require jq || finish

sandbox=$(mktemp -d)
trap 'rm -rf "$sandbox"' EXIT
mkdir -p "$sandbox/path" "$sandbox/config/voxtype"
for tool in bash env jq awk sed tail tac timeout cat; do ln -s "$(command -v "$tool")" "$sandbox/path/$tool"; done
stub() { cat >"$sandbox/path/$1"; chmod +x "$sandbox/path/$1"; }

stub voxtype <<'STUB'
#!/usr/bin/env bash
[[ $* == "setup gpu --status" ]] && printf '=== Voxtype Backend Status ===\n\nActive backend: GPU (Vulkan)\n'
STUB
stub systemctl <<'STUB'
#!/usr/bin/env bash
exit 0
STUB
stub journalctl <<'STUB'
#!/usr/bin/env bash
cat <<'LOG'
2026-09-14T14:58:51+02:00 host voxtype[1]: 2026-09-14T12:58:51Z  INFO Transcribing 20.1s of audio...
2026-09-14T14:59:11+02:00 host voxtype[1]: 2026-09-14T12:59:11Z  INFO Transcription completed in 2.21s: "Het eerste wat we nu met Ansible gaan beheren is h..."
2026-09-14T14:59:11+02:00 host voxtype[1]: 2026-09-14T12:59:11Z  INFO Transcribed: "Het eerste wat we nu met Ansible gaan beheren is het managen van de S3 locaties"
2026-09-15T09:00:00+02:00 host voxtype[1]: 2026-09-15T07:00:00Z  INFO Transcribing 3.0s of audio...
2026-09-15T09:00:01+02:00 host voxtype[1]: 2026-09-15T07:00:01Z  ERROR Transcription failed: model not loaded
2026-09-18T11:32:52+02:00 host voxtype[1]: 2026-09-18T09:32:52Z  INFO Transcribing 5.2s of audio...
2026-09-18T11:32:54+02:00 host voxtype[1]: 2026-09-18T09:32:54Z  INFO Transcription completed in 1.98s: "Thank you."
2026-09-18T11:32:54+02:00 host voxtype[1]: 2026-09-18T09:32:54Z  INFO Transcribed: "Thank you."
LOG
STUB
cat >"$sandbox/config/voxtype/config.toml" <<'TOML'
[hotkey]
key = "RIGHTALT"
mode = "push_to_talk"

[audio]
max_duration_secs = 20

[whisper]
model = "large-v3-turbo"
language = ["en", "nl"]

[output]
mode = "type"
TOML

out=$(env -i PATH="$sandbox/path" HOME="$sandbox" XDG_CONFIG_HOME="$sandbox/config" bash "$ROOT/bin/desktop-dictation-details")

check "the settings are read from voxtype's config" \
  test "$(jq -c '[.model, .languages, .key, .maxSeconds, .output]' <<<"$out")" = '["large-v3-turbo",["en","nl"],"Right Alt, hold",20,"type"]'
check "and the GPU backend from voxtype itself" test "$(jq -r .backend <<<"$out")" = "GPU (Vulkan)"
check "the newest dictation comes first" test "$(jq -r '.recent[0].text' <<<"$out")" = "Thank you."
check "the transcript is the full one, not the line cut at fifty characters" \
  test "$(jq -r '.recent[1].text' <<<"$out")" = "Het eerste wat we nu met Ansible gaan beheren is het managen van de S3 locaties"
check "each keeps how long was spoken, and how long it took" \
  test "$(jq -c '.recent[1] | [.spoken, .took, .at]' <<<"$out")" = '[20.1,2.21,"2026-09-14 14:59"]'
check "a dictation that failed is left out, and does not borrow the next one's text" \
  test "$(jq '.recent | length' <<<"$out")" = 2

rm "$sandbox/path/voxtype"
check "without voxtype it says so" \
  test "$(env -i PATH="$sandbox/path" HOME="$sandbox" bash "$ROOT/bin/desktop-dictation-details")" = '{"installed":false}'

finish
