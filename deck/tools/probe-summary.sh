#!/bin/bash
# Summarize the last N seconds of a gameplay probe (the gameplay part of the run):
# fps reported by the game, GPU busy %, busiest-thread and process CPU %,
# fastest core clock and APU power.
# usage: probe-summary.sh [seconds=40]
set -u
n="${1:-40}"
probe="$HOME/.cache/v8-staging/probe"
grep -a -q "stage 'gameplay'" "$probe/v8_latest.log" && echo "reached gameplay: yes" || echo "reached gameplay: NO"
grep -a "HostFpsTitle" "$probe/v8_latest.log" | tail -n "$n" |
  awk -F'fps=' '{split($2, a, " "); s += a[1]; c++; if (min == "" || a[1] < min) min = a[1]}
       END {if (c) printf "fps avg=%.1f min=%.1f (last %d s)\n", s / c, min, c}'
tail -n "$((n + 1))" "$probe/gpu_busy.txt" |
  awk '$3 == "-" {pt = ""; next}
       pt != "" {g += $2; t += $3 - pt; p += $4 - pp; f += $5; w += $6; c++}
       {pt = $3; pp = $4}
       END {if (c) printf "gpu busy=%.0f%%  main thread cpu=%.0f%%  process cpu=%.0f%%  fastest core=%.0f MHz  apu power=%.1f W (%d samples)\n",
            g / c, t / c, p / c, f / c / 1000, w / c / 1000000, c}'
