#!/bin/bash
# Drive the game into an arena with the project's own soak input script
# (tools/recompone-v8-2/run_reference_soak.py build_input_script, slot 0) in a
# throwaway profile, and capture presented gameplay frames. Never touches the
# real profiles.
# usage: probe-gameplay.sh <seconds> [KEY=VALUE ...] [env:NAME=VALUE ...]
#   KEY=VALUE overrides interface.ini; env:NAME=VALUE goes to the game's environment.
set -u
seconds="$1"
shift
A="$HOME/Games/Quiver Launcher/Apps/Vigilante8Classic"
probe="$HOME/.cache/v8-staging/probe"
rm -rf "$probe"
mkdir -p "$probe/captures"
cp "$A/interface.ini" "$probe/interface.ini"
ini_overrides=()
game_env=()
for arg in "$@"; do
  case "$arg" in
    env:*) game_env+=("${arg#env:}") ;;
    *) ini_overrides+=("$arg") ;;
  esac
done
if [ "${#ini_overrides[@]}" -gt 0 ]; then
  printf '%s\n' "${ini_overrides[@]}" > "$probe/overrides.ini"
  (cd "$HOME" && python3 -I "$HOME/.cache/v8-staging/tools/ini_patch.py" "$probe/interface.ini" "$probe/overrides.ini")
fi
# Once a second while the game runs: GPU busy %, CPU jiffies of the game's
# busiest thread and of the whole process (100 jiffies/s = one full core),
# the fastest core's clock (kHz) and APU power (uW). "-" when not running yet.
amdgpu_hwmon="$(grep -l '^amdgpu$' /sys/class/hwmon/hwmon*/name | head -1 | xargs dirname)"
( for _ in $(seq 1 "$seconds"); do
    gpu="$(cat /sys/class/drm/card*/device/gpu_busy_percent 2>/dev/null | head -1)"
    pid="$(pgrep -x 'Vigilante8PC.ex' | head -1)"
    thread="-" total="-"
    if [ -n "$pid" ]; then
      thread="$(for t in /proc/"$pid"/task/*/stat; do awk '{print $14 + $15}' "$t" 2>/dev/null; done | sort -n | tail -1)"
      total="$(awk '{print $14 + $15}' /proc/"$pid"/stat 2>/dev/null)"
    fi
    khz="$(cat /sys/devices/system/cpu/cpu*/cpufreq/scaling_cur_freq 2>/dev/null | sort -n | tail -1)"
    power="$(cat "$amdgpu_hwmon/power1_average" 2>/dev/null)"
    printf '%s %s %s %s %s %s\n' "$(date +%s)" "${gpu:--}" "${thread:--}" "${total:--}" "${khz:--}" "${power:--}"
    sleep 1
  done ) > "$probe/gpu_busy.txt" &
cat > "$probe/input.txt" <<'EOF'
# Same timeline as run_reference_soak.py build_input_script(slot=0)
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
w() { local p="Z:$1"; printf '%s' "${p//\//\\}"; }

# The first two match the Steam shortcut's launch options; env: args override them.
bash "$HOME/.cache/v8-staging/tools/v8-boot-test.sh" "$seconds" \
  RECOMPONE_DIRECT_TERRAIN=1 \
  DOTNET_GCgen0size=0x10000000 \
  RECOMPONE_USER_DATA_DIR="$(w "$probe")" \
  RECOMPONE_V82_QUEST_SAVE_PATH="$(w "$probe/quest-progress.json")" \
  RECOMPONE_LOG_PATH="$(w "$probe/v8_latest.log")" \
  RECOMPONE_CAPTURE_DIR="$(w "$probe/captures")" \
  RECOMPONE_INPUT_FILE="$(w "$probe/input.txt")" \
  RECOMPONE_DISABLE_LIVE_INPUT=1 \
  RECOMPONE_V82_SOAK=1 \
  RECOMPONE_SOAK_TEARDOWN_FRAMES=2400 \
  RECOMPONE_MUTE=1 \
  RECOMPONE_SUPPRESS_RUMBLE=1 \
  RECOMPONE_CAPTURE_SCRIPTED_STAGE=gameplay \
  RECOMPONE_PRESENTATION_CAPTURE=1 \
  RECOMPONE_PRESENTATION_RESOLUTION=1280x720 \
  RECOMPONE_PRESENTATION_CAPTURE_BURST_FRAMES=3 \
  RECOMPONE_PRESENTATION_CAPTURE_BURST_LABEL=gameplay \
  "${game_env[@]}"
find "$probe/captures" -type f | head -20
