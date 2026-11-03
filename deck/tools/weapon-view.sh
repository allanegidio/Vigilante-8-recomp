#!/bin/bash
# Fire one weapon from a held scene and capture its flight, to compare looks
# between builds. Every vehicle is pinned from gameplay frame 30, with two AI
# cars placed ahead as targets; L2 fires at gameplay poll 340, and 90 presents
# (about 1.5 s) are captured from there. Silent, hidden and unthrottled.
# usage: [V8_TEST_EXE=<exe beside the installed one>] weapon-view.sh <label> [kind=4] [player type=0] [arena slot]
#   kinds: 1 rockets, 2 missiles, 3 cannon, 4 mortar, 5 mines, 6 flamethrower, 7 special
# The run is kept in ~/.cache/v8-staging/views/<label>/.
set -u
label="$1"
kind="${2:-4}"
type="${3:-0}"
arena="${4:-}"
tools="$HOME/.cache/v8-staging/tools"
views="$HOME/.cache/v8-staging/views"
inputs="$HOME/.cache/v8-staging/inputs"
mkdir -p "$views" "$inputs"
input="$inputs/weapon-view.txt"
cat > "$input" <<'EOF'
# Menu timeline of run_reference_soak.py build_input_script(slot=0)
540+3=START
900+3=START
1020+2=SELECT
1080+3=CROSS
1200+2=SELECT
1260+3=CROSS
1380+2=SELECT
2020+3=CROSS
2220+2=SELECT
2280+3=CROSS
2400+2=SELECT
2460+3=CROSS
2580+2=SELECT
2640+3=CROSS
[gameplay]
340+8=L2
EOF
w() { local p="Z:$1"; printf '%s' "${p//\//\\}"; }
arena_env=()
[ -n "$arena" ] && arena_env=("env:RECOMPONE_V82_ARENA_SLOT_SEQUENCE=$arena")

bash "$tools/probe-gameplay.sh" 240 \
  "env:RECOMPONE_INPUT_FILE=$(w "$input")" \
  "env:RECOMPONE_V82_PLAYER_TYPE=$type" \
  "env:RECOMPONE_V82_SOAK_START_KIND=$kind" \
  env:RECOMPONE_V82_SOAK_POWERUPS=0 \
  env:RECOMPONE_V82_SOAK_NO_AUTOINPUT=1 \
  env:RECOMPONE_V82_PROOF_HOLD_PLAYER_FRAME=30 \
  env:RECOMPONE_V82_PROOF_EDGE_VEHICLES=1 \
  env:RECOMPONE_V82_PROOF_EDGE_VEHICLE_OFFSET=3 \
  env:RECOMPONE_V82_PROOF_EDGE_VEHICLE_FORWARD=10 \
  env:RECOMPONE_SOAK_TEARDOWN_FRAMES=330 \
  env:RECOMPONE_SCRIPT_EXIT_AFTER_STAGE=soak_teardown \
  env:RECOMPONE_SCRIPT_EXIT_AFTER_STAGE_VISITS=1 \
  env:RECOMPONE_DISABLE_SCRIPT_STAGE_CAPTURES=1 \
  env:RECOMPONE_DISPLAY_PROBE_IMAGES=0 \
  env:RECOMPONE_PRESENTATION_CAPTURE_BURST_LABEL=gameplay_0340 \
  env:RECOMPONE_PRESENTATION_CAPTURE_BURST_FRAMES=90 \
  env:RECOMPONE_UNTHROTTLED=1 \
  "${arena_env[@]}" > /dev/null
rm -rf "${views:?}/$label"
mv "$HOME/.cache/v8-staging/probe" "$views/$label"
echo "$label: $(ls "$views/$label/captures" | wc -l) captures," \
  "fired=$(grep -ac 'weapon-fired' "$views/$label/v8_latest.log")"
