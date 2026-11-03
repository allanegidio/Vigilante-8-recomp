#!/bin/bash
# Arm and fire every weapon kind with each car: one silent, hidden, unthrottled
# run per car. Kinds: 1 rockets, 2 missiles, 3 cannon, 4 mortar, 5 mines,
# 6 flamethrower, 7 the car's special.
# The soak arms kind k at gameplay frame 30+360*(k-1) with 99 ammo. The input
# presses L2 three times per window and marks two captures after the first shot.
# Each run's log and captures land in ~/.cache/v8-staging/sweep/<type>/.
# usage: weapon-sweep.sh [player types ...]   (default: retail 0-17, guests 64-76)
set -u
tools="$HOME/.cache/v8-staging/tools"
sweep="$HOME/.cache/v8-staging/sweep"
mkdir -p "$sweep"
types=("$@")
[ "${#types[@]}" -gt 0 ] || types=($(seq 0 17) $(seq 64 76))

input="$sweep/input.txt"
{
  cat <<'EOF'
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
EOF
  # Gameplay poll p is about game frame p/2.
  for window in 0 1 2 3 4 5 6; do
    base=$((30 + 360 * window))
    for shot in 40 120 200; do echo "$((2 * (base + shot)))+8=L2"; done
    for mark in 50 70; do echo "$((2 * (base + mark)))+1=NONE"; done
  done
} > "$input"
w() { local p="Z:$1"; printf '%s' "${p//\//\\}"; }

for t in "${types[@]}"; do
  run="$sweep/$t"
  rm -rf "$run"
  mkdir -p "$run/captures"
  bash "$tools/v8-boot-test.sh" 420 \
    RECOMPONE_DIRECT_TERRAIN=1 \
    DOTNET_GCgen0size=0x10000000 \
    RECOMPONE_USER_DATA_DIR="$(w "$run")" \
    RECOMPONE_V82_QUEST_SAVE_PATH="$(w "$run/quest-progress.json")" \
    RECOMPONE_LOG_PATH="$(w "$run/v8_latest.log")" \
    RECOMPONE_CAPTURE_DIR="$(w "$run/captures")" \
    RECOMPONE_INPUT_FILE="$(w "$input")" \
    RECOMPONE_DISABLE_LIVE_INPUT=1 \
    RECOMPONE_SUPPRESS_RUMBLE=1 \
    RECOMPONE_UNTHROTTLED=1 \
    RECOMPONE_V82_PLAYER_TYPE="$t" \
    RECOMPONE_V82_SOAK=1 \
    RECOMPONE_V82_SOAK_START_KIND=1 \
    RECOMPONE_V82_SOAK_POWERUPS=0 \
    RECOMPONE_V82_SOAK_NO_AUTOINPUT=1 \
    RECOMPONE_SOAK_HEARTBEAT_FRAMES=60 \
    RECOMPONE_SOAK_TEARDOWN_FRAMES=2560 \
    RECOMPONE_SCRIPT_EXIT_AFTER_STAGE=soak_teardown \
    RECOMPONE_SCRIPT_EXIT_AFTER_STAGE_VISITS=1 \
    RECOMPONE_TRACE_V8_SPECIAL=1 \
    RECOMPONE_CAPTURE_SCRIPTED_STAGE=gameplay \
    RECOMPONE_DISABLE_SCRIPT_STAGE_CAPTURES=1 \
    RECOMPONE_DISPLAY_PROBE_IMAGES=0 \
    RECOMPONE_PRESENTATION_CAPTURE=1 \
    RECOMPONE_PRESENTATION_RESOLUTION=1280x720 \
    > "$run/boot-test.out" 2>&1
  echo "type=$t $(date +%H:%M:%S) armed=$(grep -ac 'weapon-armed' "$run/v8_latest.log" 2>/dev/null)" \
    "fired=$(grep -ac 'weapon-fired' "$run/v8_latest.log" 2>/dev/null)" \
    "captures=$(ls "$run/captures" | wc -l)"
done
