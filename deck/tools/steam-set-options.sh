#!/bin/bash
# Set the launch options of one Steam shortcut (Steam is stopped and restarted).
# usage: steam-set-options.sh "<app name>" "<launch options>"
set -u
name="$1"
options="$2"
tools="$HOME/.cache/v8-staging/tools"
shortcuts="$HOME/.local/share/Steam/userdata/84908674/config/shortcuts.vdf"
stamp="$(date +%Y%m%d-%H%M%S)"

if pgrep -x reaper > /dev/null || pgrep -x Vigilante8PC.ex > /dev/null; then
  echo "a game is running; abort"; exit 1
fi
steam_pid="$(pgrep -xo steam)"
mapfile -d '' steam_env < "/proc/$steam_pid/environ"
mapfile -d '' steam_cmd < "/proc/$steam_pid/cmdline"
game_mode=no
pgrep -x gamescope > /dev/null && game_mode=yes
echo "stopping Steam (game mode: $game_mode)..."
if [ "$game_mode" = yes ]; then
  systemctl --user stop steam-launcher.service
else
  steam -shutdown > /dev/null 2>&1
  timeout 90 tail --pid="$steam_pid" -f /dev/null
fi
if pgrep -x steam > /dev/null; then
  echo "Steam still running; abort"; exit 1
fi
cp -p "$shortcuts" "$shortcuts.bak-before-options-$stamp"
cd "$HOME" && python3 -I "$tools/steam_vdf.py" edit "$shortcuts" - "$name" "$options" &&
  python3 -I "$tools/steam_vdf.py" list "$shortcuts" | grep -E "round-trip|$name" ||
  { echo "edit failed; restoring"; cp -p "$shortcuts.bak-before-options-$stamp" "$shortcuts"; }
echo "starting Steam..."
if [ "$game_mode" = yes ]; then
  systemctl --user start steam-launcher.service
else
  systemd-run --user --scope --unit="steam-relaunch-$stamp" --collect \
    env -i "${steam_env[@]}" "${steam_cmd[@]}" > /dev/null 2>&1 < /dev/null &
  disown
fi
