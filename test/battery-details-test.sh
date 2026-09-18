#!/usr/bin/env bash
# The battery panel's figures, against fake /sys/class/power_supply trees.
#
# The cases are the ones a laptop can be: this Dell, which reports charge (µAh) rather
# than energy and keeps charge limits the firmware ignores outside its Custom mode; a
# ThinkPad-style battery that reports energy and always applies its limit; a wireless
# mouse, which is a battery too and must not be taken for the laptop's; and a desktop.
source "$(dirname "$0")/lib.sh"

require jq || finish

sandbox=$(mktemp -d)
trap 'rm -rf "$sandbox"' EXIT

supply() { # tree name key=value...
  local dir="$sandbox/$1/$2"
  shift 2
  mkdir -p "$dir"
  for pair in "$@"; do printf '%s\n' "${pair#*=}" >"$dir/${pair%%=*}"; done
}
status() { DESKTOP_POWER_SUPPLY_PATH="$sandbox/$1" "$ROOT/bin/desktop-battery-details"; }
field() { jq -r "$2" <<<"$(status "$1")"; }

# The mouse sorts first, so taking the first battery found would take it.
supply dell hidpp_battery_0 type=Battery scope=Device capacity=40
supply dell AC type=Mains online=1
supply dell BAT0 type=Battery status="Not charging" charge_full=6027000 charge_full_design=8386000 \
  voltage_min_design=11700000 voltage_now=12623000 current_now=1000 cycle_count=228 \
  charge_control_start_threshold=50 charge_control_end_threshold=90 \
  charge_types="Trickle Fast Standard [Adaptive] Custom"

check "a peripheral's battery is not taken for the laptop's" test "$(field dell .cycles)" = 228
check "charge is turned into energy at the design voltage" test "$(field dell .full_wh)" = 70.5
check "and health is what is left of the design capacity" test "$(field dell .health)" = 72
check "the charging mode is the one in brackets" test "$(field dell .mode)" = Adaptive
check "the limits are reported for the panel to weigh against the mode" \
  test "$(field dell '"\(.limit_start)-\(.limit_end)"')" = 50-90
check "a plugged-in laptop says so" test "$(field dell .ac)" = true

# Discharging, current_now is negative on some drivers; a draw is a draw.
supply thinkpad AC type=Mains online=0
supply thinkpad BAT0 type=Battery status=Discharging energy_full=50000000 energy_full_design=57000000 \
  power_now=-8400000 cycle_count=0 charge_control_end_threshold=80

check "energy is read directly where the driver reports it" test "$(field thinkpad .full_wh)" = 50.0
check "power is instantaneous, and positive" test "$(field thinkpad .watts)" = 8.4
check "a cycle count of zero is not a reading" test "$(field thinkpad .cycles)" = null
check "no charge_types means no mode, so the limit stands" test "$(field thinkpad .mode)" = null
check "on battery is not plugged in" test "$(field thinkpad .ac)" = false

mkdir -p "$sandbox/desktop"
supply desktop hidpp_battery_0 type=Battery scope=Device capacity=40
check "a desktop has no battery, whatever its mouse has" test "$(status desktop)" = '{"present":false}'

finish
