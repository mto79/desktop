#!/usr/bin/env bash
# The weather on the dashboard's start page. What is checked: with no place set, the answer
# says it is invented and how to fix that; a place by name is looked up once and remembered;
# coordinates written down are used as they are; Open-Meteo's answer is turned into what the
# tile draws; it is asked at most every half hour; and when it is out of reach the last
# answer is given again rather than nothing.
#
# curl is a stub that serves a geocoding answer and a forecast, and writes down each URL.
source "$(dirname "$0")/lib.sh"

require jq || finish

sandbox=$(mktemp -d)
trap 'rm -rf "$sandbox"' EXIT
stubs="$sandbox/stubs"
mkdir -p "$stubs" "$sandbox/config/desktop/dashboard"

cat >"$sandbox/geocode.json" <<'JSON'
{"results":[{"name":"Utrecht","latitude":52.09,"longitude":5.12}]}
JSON
cat >"$sandbox/forecast.json" <<'JSON'
{"current":{"temperature_2m":5.4,"apparent_temperature":2.2,"relative_humidity_2m":76,"wind_speed_10m":6.8,"weather_code":61,"is_day":1},
 "daily":{"time":["2026-11-11","2026-11-12","2026-11-13"],"weather_code":[61,3,0],
  "temperature_2m_max":[6.4,9.8,9.9],"temperature_2m_min":[3.6,1.4,4.0],
  "sunrise":["2026-11-11T07:52","2026-11-12T07:54","2026-11-13T07:56"],
  "sunset":["2026-11-11T16:53","2026-11-12T16:52","2026-11-13T16:50"]}}
JSON
cat >"$stubs/curl" <<STUB
#!/usr/bin/env bash
echo "\$*" >>"$sandbox/asked"
[[ -e "$sandbox/offline" ]] && exit 6
case "\$*" in
*geocode.example*) cat "$sandbox/geocode.json" ;;
*forecast.example*) cat "$sandbox/forecast.json" ;;
*) exit 22 ;;
esac
STUB
chmod +x "$stubs/curl"

weather() {
  PATH="$stubs:$PATH" XDG_CONFIG_HOME="$sandbox/config" XDG_CACHE_HOME="$sandbox/cache" \
    DESKTOP_WEATHER_FORECAST=https://forecast.example/v1/forecast \
    DESKTOP_WEATHER_GEOCODE=https://geocode.example/v1/search \
    bash "$ROOT/bin/desktop-weather" --json
}
conf="$sandbox/config/desktop/dashboard/weather.conf"

out=$(weather)
check "with no place set, it says the weather is invented" test "$(jq .connected <<<"$out")" = false
check "and how to set one" grep -q 'weather.conf' <<<"$(jq -r .how <<<"$out")"
check "without asking anyone anything" test ! -e "$sandbox/asked"

echo "place = Utrecht   # home" >"$conf"
out=$(weather)
check "a place by name is looked up" grep -q 'geocode.example.*name=Utrecht' "$sandbox/asked"
check "and its forecast is asked for where it is" grep -q 'forecast.example.*latitude=52.09.*longitude=5.12' "$sandbox/asked"
check "the answer is the place's" test "$(jq -r '[.connected, .place] | join(" ")' <<<"$out")" = "true Utrecht"
check "now, rounded and described" \
  test "$(jq -c '.now | [.temp, .feels, .humidity, .wind, .text, .day]' <<<"$out")" = '[5,2,76,7,"Rain",true]'
check "three days, today first" \
  test "$(jq -c '[.days[] | [.day, .max, .min, .text]]' <<<"$out")" = '[["Today",6,4,"Rain"],["Thu",10,1,"Overcast"],["Fri",10,4,"Clear"]]'
check "and when the sun rises and sets" test "$(jq -r '"\(.sun.rise) \(.sun.set)"' <<<"$out")" = "07:52 16:53"

: >"$sandbox/asked"
weather >/dev/null
check "within the half hour, nobody is asked again" test ! -s "$sandbox/asked"

touch -d '-1 hour' "$sandbox/cache/desktop/dashboard/weather.json"
weather >/dev/null
check "after it, the forecast is asked again" grep -q forecast.example "$sandbox/asked"
check "but where Utrecht is, is remembered" lacks geocode.example "$sandbox/asked"

touch -d '-1 hour' "$sandbox/cache/desktop/dashboard/weather.json"
touch "$sandbox/offline"
out=$(weather)
check "out of reach, the last answer is given again" test "$(jq -r '[.connected, .now.temp] | join(" ")' <<<"$out")" = "true 5"
rm "$sandbox/offline"

# A name alone can be another town of that name: "Den Haag" alone is in South Africa.
printf 'place = Den Haag\ncountry = nl\n' >"$conf"
: >"$sandbox/asked"
weather >/dev/null
check "a country narrows where a name is looked up" grep -q 'name=Den Haag.*countryCode=NL\|name=Den%20Haag.*countryCode=NL' "$sandbox/asked"

printf 'latitude = 51.92\nlongitude = 4.48\nplace = Rotterdam\n' >"$conf"
: >"$sandbox/asked"
out=$(weather)
check "coordinates written down are used as they are" grep -q 'latitude=51.92.*longitude=4.48' "$sandbox/asked"
check "with nobody asked where they are" lacks geocode.example "$sandbox/asked"
check "and a new place is not answered from the old one's cache" test "$(jq -r .place <<<"$out")" = Rotterdam

check "the brief carries it to the start page" grep -q 'desktop-weather --json' "$ROOT/bin/desktop-brief"

finish
