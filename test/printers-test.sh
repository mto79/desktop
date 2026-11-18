#!/usr/bin/env bash

# desktop-printers: the printers within reach, asked over IPP for their state and ink, the
# worst for the bar, and a popup once for a new problem or a low ink.

source "$(dirname "$0")/lib.sh"

sandbox=$(mktemp -d)
trap 'rm -rf "$sandbox"' EXIT
mkdir -p "$sandbox/stubs" "$sandbox/run"

# No queue added; one printer announcing itself; ipptool answering as an HP does, from a file.
printf '#!/usr/bin/env bash\nexit 0\n' >"$sandbox/stubs/lpstat"
printf '#!/usr/bin/env bash\necho ipp://printer.local:631/ipp/print\n' >"$sandbox/stubs/ippfind"
cat >"$sandbox/stubs/ipptool" <<STUB
#!/usr/bin/env bash
cat "$sandbox/answer"
STUB
chmod +x "$sandbox/stubs/"*

# answer <state> <reasons> <black level>
answer() {
  cat >"$sandbox/answer" <<EOF
        printer-info (textWithoutLanguage) = OfficeJet \\[130BA6]
        printer-make-and-model (textWithoutLanguage) = HP OfficeJet 250 Mobile Series
        printer-more-info (uri) = http://printer.local/
        printer-state (enum) = $1
        printer-state-reasons (keyword) = $2
        queued-job-count (integer) = 0
        marker-names (1setOf nameWithoutLanguage) = tri-color ink,black ink
        marker-colors (1setOf nameWithoutLanguage) = #00FFFF#FF00FF#FFFF00,#000000
        marker-levels (1setOf integer) = 40,$3
EOF
}

printers() {
  env -i PATH="$sandbox/stubs:/usr/bin:/bin" XDG_RUNTIME_DIR="$sandbox/run" \
    DESKTOP_PRINTERS_SEND="$sandbox/sent" python3 "$ROOT/bin/desktop-printers" "$@"
}
out="$sandbox/run/desktop/printers.json"
: >"$sandbox/sent"

answer idle none 50
printers
check "a printer on the network is found and asked, though it was never added" \
  test "$(jq -r '.printers[0].name' "$out")" = "OfficeJet [130BA6]"
check "  its inks by name, without the word ink" \
  test "$(jq -r '[.printers[0].inks[] | "\(.name)=\(.level)"] | join(" ")' "$out")" = "tri-color=40 black=50"
check "  its own web page to open" test "$(jq -r '.printers[0].web' "$out")" = "http://printer.local/"
check "  idle, and nothing said the first time" test "$(jq -r .worst "$out")-$(wc -l <"$sandbox/sent")" = "idle-0"

answer stopped media-empty-error 50
printers
check "out of paper is a problem, said as one" test "$(jq -r '.printers[0].problems[0]' "$out")" = "out of paper"
check "  red in the bar" test "$(jq -r .worst "$out")" = error
check "  and a popup, urgent" grep -q $'^critical\tOfficeJet \\[130BA6\\]: out of paper' "$sandbox/sent"
: >"$sandbox/sent"
printers
check "  said once, not every two minutes" test ! -s "$sandbox/sent"

answer idle media-low-report 10
printers
check "a printer only chatting -report is no problem" test "$(jq -r '.printers[0].problems | length' "$out")" = 0
check "an ink under 15% is low, amber in the bar" test "$(jq -r .worst "$out")" = low
check "  and a popup with what is left" grep -q $'^normal\tOfficeJet \\[130BA6\\]: black low\t10% left.' "$sandbox/sent"

printf '#!/usr/bin/env bash\nexit 0\n' >"$sandbox/stubs/ippfind"
printers
check "no printer on this network: nothing for the bar" test "$(jq -r '.worst' "$out")" = none

check "the bar knows the printers" grep -q '"printers": printers' "$ROOT/shell/Bar/WidgetRegistry.qml"

finish
