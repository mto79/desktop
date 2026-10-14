#!/usr/bin/env bash
# The discography on the now-playing card, from bin/desktop-discography. What goes wrong
# is the guessing: a featured artist searched for as part of the name, a live bootleg or
# a compilation counted as an album, the remaster on the track not matching the album on
# the shelf, a slow second request taken to mean "no albums" and kept for a month.
#
# curl is a stub answering from files. Nothing here reaches MusicBrainz.
source "$(dirname "$0")/lib.sh"
require jq || finish

DISCOGRAPHY="$ROOT/bin/desktop-discography"
sandbox=$(mktemp -d)
trap 'rm -rf "$sandbox"' EXIT
stubs="$sandbox/bin" answers="$sandbox/answers"
mkdir -p "$stubs" "$answers"

# Logs what was searched for, answers artist and release-group searches from files, and
# writes a cover for every id named in $answers/covers.
cat >"$stubs/curl" <<STUB
#!/usr/bin/env bash
query="" out=() url=""
while ((\$#)); do
  case \$1 in
  --data-urlencode) query=\${2#query=}; shift ;;
  -o) out+=("\$2"); shift ;;
  -A | --data | --max-time) shift ;;
  -*) ;;
  *) url=\$1 ;;
  esac
  shift
done
echo "\$query" >>"$sandbox/asked"
for f in "\${out[@]}"; do
  id=\$(basename "\$f" .jpg)
  grep -qx "\$id" "$answers/covers" 2>/dev/null && echo jpeg >"\$f"
done
((\${#out[@]})) && exit 0
case \$url in
*/artist/) cat "$answers/artist" ;;
*/release-group/)
  case \$query in
  *"NOT secondarytype"*primarytype* | *primarytype*"NOT secondarytype"*) cat "$answers/albums" ;;
  *) cat "$answers/releases" 2>/dev/null || echo '{"release-groups": []}' ;;
  esac ;;
esac
STUB
chmod +x "$stubs/curl"
# Not a second's wait between requests in a test.
printf '#!/bin/sh\n' >"$stubs/sleep" && chmod +x "$stubs/sleep"

run() {
  rm -f "$sandbox/asked"
  PATH="$stubs:$PATH" XDG_CACHE_HOME="$sandbox/cache" "$DISCOGRAPHY" "$@"
}

rg() { # id title date [secondary type]
  printf '{"id": "%s", "title": "%s", "first-release-date": "%s", "secondary-types": [%s]}' \
    "$1" "$2" "$3" "${4:+\"$4\"}"
}

echo '{"artists": [{"id": "a1", "name": "Radiohead", "score": 100}, {"id": "a2", "name": "radiohead 3", "score": 57}]}' >"$answers/artist"
printf '{"release-groups": [%s, %s, %s, %s, %s]}' \
  "$(rg r3 "OK Computer" 1997-05-21)" "$(rg r1 "Pablo Honey" 1993-02-22)" \
  "$(rg r9 "1995-06-10: Cabaret Metro" 1995-06-10 Live)" "$(rg r8 "Paragons of Virtue" 1996 Compilation)" \
  "$(rg r2 "The Bends" 1994-11-29)" >"$answers/albums"
printf 'r1\nr3\n' >"$answers/covers"

out=$(run "Radiohead feat. Someone Else" "OK Computer (Remastered)")
check "a featured artist is left out of the search" grep -q '^artist:"Radiohead"$' "$sandbox/asked"
check "studio albums only, oldest first" \
  test "$(jq -r '[.albums[].title] | join(", ")' <<<"$out")" = "Pablo Honey, The Bends, OK Computer"
check "the album playing is the one marked, its edition aside" \
  test "$(jq -r '[.albums[] | select(.current).title] | join(",")' <<<"$out")" = "OK Computer"
check "a year, not a date" test "$(jq -r '.albums[0].year' <<<"$out")" = 1993
check "a cover where one was fetched, none where there was not" \
  test "$(jq -r '[.albums[] | (.cover != "")] | map(tostring) | join(" ")' <<<"$out")" = "true false true"

run "Radiohead" "" >/dev/null
check "a second look is answered from the cache" test ! -s "$sandbox/asked"

rm -rf "$sandbox/cache"
echo '{"artists": [{"id": "x", "name": "Someone Else Entirely", "score": 61}]}' >"$answers/artist"
out=$(run "Some YouTube Channel - Topic" "")
check "an artist the search is not sure of has no discography" \
  test "$(jq -c '[.artist, .albums]' <<<"$out")" = '["",[]]'
check "the Topic suffix is not searched for" grep -q '^artist:"Some YouTube Channel"$' "$sandbox/asked"

rm -rf "$sandbox/cache"
echo '{"artists": [{"id": "a7", "name": "New Band", "score": 100}]}' >"$answers/artist"
echo '{"release-groups": []}' >"$answers/albums"
printf '{"release-groups": [%s, %s]}' "$(rg s2 "Second Single" 2025)" "$(rg s1 "First EP" 2023)" >"$answers/releases"
out=$(run "New Band" "")
check "no album yet: the EPs and singles stand in" \
  test "$(jq -r '.kind + ": " + ([.albums[].title] | join(", "))' <<<"$out")" = "releases: First EP, Second Single"

rm -rf "$sandbox/cache"
echo 'not json' >"$answers/albums"
rm -f "$answers/releases"
out=$(run "New Band" "")
check "a failed album request prints nothing found" test "$(jq -c .albums <<<"$out")" = "[]"
check "and is not kept, so the next track asks again" test ! -e "$sandbox/cache/desktop/discography/new_band.json"

check "no artist is a usage error" bash -c "! '$DISCOGRAPHY' 2>/dev/null"

finish
