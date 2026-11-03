#!/bin/bash
# Sample CPU clocks, APU power, GPU busy and the game's CPU use once a second
# while Allan plays, without touching the game. Read-only.
# usage: watch-clocks.sh <seconds> [out file=~/.cache/v8-staging/clocks.txt]
set -u
seconds="$1"
out="${2:-$HOME/.cache/v8-staging/clocks.txt}"
hwmon="$(grep -l '^amdgpu$' /sys/class/hwmon/hwmon*/name | head -1 | xargs dirname)"
echo "# time mode max_mhz avg_mhz apu_w gpu_busy game_cpu% main_thread_cpu% epp" > "$out"
prev_total="" prev_thread=""
for _ in $(seq 1 "$seconds"); do
  freqs="$(cat /sys/devices/system/cpu/cpu*/cpufreq/scaling_cur_freq)"
  max="$(sort -n <<< "$freqs" | tail -1)"
  avg="$(awk '{s += $1; c++} END {print int(s / c)}' <<< "$freqs")"
  power="$(cat "$hwmon/power1_average")"
  gpu="$(cat /sys/class/drm/card*/device/gpu_busy_percent 2>/dev/null | head -1)"
  mode=desktop
  pgrep -x gamescope > /dev/null && mode=game
  pid="$(pgrep -x Vigilante8PC.ex | head -1)"
  total="-" thread="-"
  if [ -n "$pid" ]; then
    total="$(awk '{print $14 + $15}' "/proc/$pid/stat" 2>/dev/null)"
    thread="$(for t in /proc/"$pid"/task/*/stat; do awk '{print $14 + $15}' "$t" 2>/dev/null; done | sort -n | tail -1)"
  fi
  game="-" main="-"
  if [ -n "$prev_total" ] && [ "$total" != "-" ]; then
    game=$((total - prev_total))
    main=$((thread - prev_thread))
  fi
  prev_total="${total/-/}" prev_thread="${thread/-/}"
  [ "$total" = "-" ] && prev_total="" && prev_thread=""
  printf '%s %s %d %d %.1f %s %s %s %s\n' "$(date +%H:%M:%S)" "$mode" "$((max / 1000))" "$((avg / 1000))" \
    "$(awk "BEGIN {print $power / 1000000}")" "${gpu:--}" "$game" "$main" \
    "$(cat /sys/devices/system/cpu/cpu0/cpufreq/energy_performance_preference)" >> "$out"
  sleep 1
done
awk '$7 != "-" {n++; mx += $3; av += $4; w += $5; g += $6; gc += $7; mt += $8}
     END {if (n) printf "while the game ran (%d s): max core %.0f MHz, avg core %.0f MHz, APU %.1f W, GPU busy %.0f%%, game cpu %.0f%%, main thread %.0f%%\n",
          n, mx / n, av / n, w / n, g / n, gc / n, mt / n; else print "the game was not running"}' "$out"
