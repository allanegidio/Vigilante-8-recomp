#!/bin/bash
# Launch a shortcut through Steam, wait for a log line, screenshot, then close it.
# usage: steam-launch-test.sh <appid> <gameid64> <log file> <log pattern> <shot.png>
set -u
appid="$1"; gameid="$2"; log="$3"; pattern="$4"; shot="$5"
compat="STEAM_COMPAT_DATA_PATH=$HOME/.local/share/Steam/steamapps/compatdata/$appid"

rm -f "$log"
steam "steam://rungameid/$gameid" > /dev/null 2>&1 &

# Wait (up to 120 s) for the log to show the pattern; tail -F also waits for
# the file to appear.
if timeout 120 grep -m1 -q -- "$pattern" <(timeout 125 tail -n +1 -F "$log" 2>/dev/null); then
  echo "pattern seen: $pattern"
else
  echo "pattern NOT seen within timeout"
fi
gamescopectl screenshot "$shot" > /dev/null 2>&1
echo "screenshot rc=$?"

# Close the game: stop every process that runs in this shortcut's prefix.
for proc in /proc/[0-9]*; do
  if { tr '\0' '\n' < "$proc/environ"; } 2>/dev/null | grep -qx -- "$compat"; then
    kill -TERM "${proc#/proc/}" 2>/dev/null
  fi
done
echo "close signal sent"
