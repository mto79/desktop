#!/usr/bin/env bash
# Config files are what we mean to ship: they parse, and none of them is state that
# the program itself owns.
#
# yazi's tokyo-night flavour once failed to parse for months: yazi renamed a key, the old
# spelling failed the whole file, and yazi silently fell back to preset settings on every
# launch. It reads as "my file manager does not match my theme", never as an error.
source "$(dirname "$0")/lib.sh"

require python3 || finish

bad=()
while IFS= read -r -d '' f; do
  python3 -c "import tomllib,sys;tomllib.load(open(sys.argv[1],'rb'))" "$f" 2>/dev/null || bad+=("${f#$ROOT/}")
done < <(find "$ROOT/config" "$ROOT/default" "$ROOT/themes" -name "*.toml" -print0 2>/dev/null)
if ((${#bad[@]} == 0)); then pass "every tracked TOML parses"; else fail "every tracked TOML parses" "${bad[*]}"; fi

bad=()
while IFS= read -r -d '' f; do
  python3 -c "import json,sys;json.load(open(sys.argv[1]))" "$f" 2>/dev/null || bad+=("${f#$ROOT/}")
done < <(find "$ROOT/config" "$ROOT/themes" "$ROOT/.claude" -name "*.json" -print0 2>/dev/null)
if ((${#bad[@]} == 0)); then pass "every tracked JSON parses"; else fail "every tracked JSON parses" "${bad[*]}"; fi

# yazi's filetype rules key off `url` or `mime`; `name` is the spelling it dropped.
bad=$(grep -rln 'name = "' "$ROOT/config/yazi" 2>/dev/null || true)
if [[ -z $bad ]]; then
  pass "no yazi rules use the retired 'name' key"
else
  fail "no yazi rules use the retired 'name' key" "$bad"
fi

# tmux 3.7 draws a message as one format overlaying the status line instead of replacing
# it, so a message-style without `fill=` paints only its own text and leaves the window
# tabs showing through beside it -- the command prompt read
# "Session name: workcode   3 notes-". tmux's own default carries fill=yellow. Every
# theme here set a bg and no fill, so every theme was broken by the upgrade.
missing=()
while IFS= read -r -d '' f; do
  while IFS= read -r line; do
    bg=$(grep -oP 'bg=\K#[0-9a-fA-F]{6}' <<<"$line") || true
    [[ -n $bg ]] || continue
    grep -q "fill=$bg" <<<"$line" || missing+=("${f#$ROOT/}: $line")
  done < <(grep -h 'message-style\|message-command-style' "$f" 2>/dev/null || true)
done < <(find "$ROOT/themes" -name tmux.conf -print0 2>/dev/null)
if ((${#missing[@]} == 0)); then
  pass "every theme fills the status line behind a tmux message"
else
  fail "every theme fills the status line behind a tmux message" "${missing[*]}"
fi

# The agent marks on tmux tabs take their colours from the theme. A theme without them draws
# the waiting mark in the tab's ordinary colour, which is to say not noticeably at all -- and
# nothing reports that, so it is checked here.
unmarked=()
while IFS= read -r -d '' f; do
  for option in @agent-waiting-colour @agent-done-colour; do
    grep -qE "^set -g $option \"#[0-9a-fA-F]{6}\"" "$f" || unmarked+=("${f#$ROOT/}: $option")
  done
done < <(find "$ROOT/themes" -name tmux.conf -print0 2>/dev/null)
if ((${#unmarked[@]} == 0)); then
  pass "every theme colours the agent marks on tmux tabs"
else
  fail "every theme colours the agent marks on tmux tabs" "${unmarked[*]}"
fi

# fish rewrites both of these itself. fish_variables holds the universal variables, and
# 4.3 writes conf.d/fish_frozen_*.fish once, when it migrates the colours and key
# bindings out of universal scope. Shipping either copies stale state over the live file
# on install: a checked-in fish_variables still carrying __fish_initialized:3800 and a
# universal fish_key_bindings made every clean install replay that migration, banner and
# all, and write the frozen file back.
state=()
[[ -e $ROOT/config/fish/fish_variables ]] && state+=("config/fish/fish_variables")
while IFS= read -r -d '' f; do state+=("${f#$ROOT/}"); done \
  < <(find "$ROOT/config/fish" -name "fish_frozen_*.fish" -print0 2>/dev/null)
if ((${#state[@]} == 0)); then
  pass "no fish-managed state files are shipped"
else
  fail "no fish-managed state files are shipped" "${state[*]}"
fi
finish
