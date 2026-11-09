#!/usr/bin/env bash
# codex and opencode were installed with `npm i -g` and never updated. What is checked: what
# npm says is behind is installed at its latest -- across a major version, which `npm update`
# would not do -- --check changes nothing, and no npm or no answer does not fail the update.
source "$(dirname "$0")/lib.sh"

UPDATE="$ROOT/bin/desktop-update-npm"
sandbox=$(mktemp -d)
trap 'rm -rf "$sandbox"' EXIT
mkdir -p "$sandbox/stubs" "$sandbox/none"
cat >"$sandbox/stubs/npm" <<STUB
#!/usr/bin/env bash
echo "\$*" >>"$sandbox/npm"
case "\$1" in
outdated) cat "$sandbox/outdated" 2>/dev/null; exit 1 ;;
i) exit 0 ;;
esac
STUB
printf '#!/usr/bin/env bash\nprintf "%%s|" "$@" >>"%s/notified"; echo >>"%s/notified"\n' "$sandbox" "$sandbox" >"$sandbox/stubs/notify-send"
chmod +x "$sandbox/stubs"/*

run() { PATH="$sandbox/stubs:/usr/bin:/bin" DESKTOP_NPM_PREFIX="$sandbox/local" bash "$UPDATE" "$@"; }

cat >"$sandbox/outdated" <<'JSON'
{"@openai/codex":{"current":"0.165.0","wanted":"0.165.0","latest":"1.0.0"},
 "opencode-ai":{"current":"1.19.5","wanted":"1.19.5","latest":"1.19.5"},
 "gone":{"wanted":"1.0.0","latest":"1.0.0"}}
JSON

run --check >"$sandbox/said"
check "--check names what is behind" grep -q '@openai/codex 0.165.0 -> 1.0.0' "$sandbox/said"
check "and installs nothing" lacks '^i ' "$sandbox/npm"

run >/dev/null
check "what is behind is installed at its latest, across a major" grep -q '^i -g --prefix .*@openai/codex@1.0.0$' "$sandbox/npm"
check "into the prefix the tools live in" grep -q -- "--prefix $sandbox/local" "$sandbox/npm"
check "what is current is left alone" lacks 'opencode-ai@' "$sandbox/npm"
check "and so is what is not installed" lacks 'gone@' "$sandbox/npm"
check "the update is said" grep -q '@openai/codex updated|0.165.0 → 1.0.0' "$sandbox/notified"

echo 'not json' >"$sandbox/outdated"
run >/dev/null && status=0 || status=$?
check "an answer npm garbled does not fail the update" test "$status" = 0
PATH="$sandbox/none" /usr/bin/bash "$UPDATE" >/dev/null && status=0 || status=$?
check "nor does no npm at all" test "$status" = 0
check "desktop-update runs it" grep -qx 'desktop-update-npm' "$ROOT/bin/desktop-update"

finish
