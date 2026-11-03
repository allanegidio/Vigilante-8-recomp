#!/bin/bash
# Boot the game under Proton 11 (Steam Linux Runtime 4) with a hidden window,
# let it run for <seconds>, then stop every process of this test.
# Tests use their own Wine prefix (~/.cache/v8-staging/prefix), never the
# Steam shortcut's (compatdata/3982178090).
# usage: v8-boot-test.sh <seconds> [NAME=VALUE ...]
set -u
A="$HOME/Games/Quiver Launcher/Apps/Vigilante8Classic"
seconds="$1"
extra_env=("${@:2}")
common="$HOME/.local/share/Steam/steamapps/common"
compat="$HOME/.cache/v8-staging/prefix"
mkdir -p "$compat"
out="$HOME/.cache/v8-staging/boot.out"
cd "$A" || exit 1

# Use the X display Steam itself runs on (Game Mode: gamescope's Xwayland, no
# auth; Desktop Mode: KWin's Xwayland, which needs the session's XAUTHORITY).
steam_env="$(tr '\0' '\n' < "/proc/$(pgrep -xo steam)/environ")"
steam_display="$(sed -n 's/^DISPLAY=//p' <<< "$steam_env")"
steam_xauthority="$(sed -n 's/^XAUTHORITY=//p' <<< "$steam_env")"

# Steam's idle suspend doesn't see this run; hold sleep off while it lasts.
inhibit=()
if systemd-inhibit --what=sleep:idle --mode=block true 2>/dev/null; then
  inhibit=(systemd-inhibit --what=sleep:idle --mode=block --who=v8-test --why="Vigilante 8 test run")
fi
# Tests are silent: Allan may be next to the Deck. SDL's dummy driver plays
# nothing, and RECOMPONE_MUTE zeroes the mix as well.
"${inhibit[@]}" timeout --signal=TERM "$seconds" env \
  V8_BOOT_TEST=1 \
  SDL_AUDIODRIVER=dummy \
  RECOMPONE_MUTE=1 \
  STEAM_COMPAT_CLIENT_INSTALL_PATH="$HOME/.local/share/Steam" \
  STEAM_COMPAT_DATA_PATH="$compat" \
  WINEDEBUG=-all \
  DISPLAY="$steam_display" \
  XAUTHORITY="$steam_xauthority" \
  RECOMPONE_WINDOW_VISIBLE=0 \
  RECOMPONE_TRACE_WINDOW_FPS=1 \
  "${extra_env[@]}" \
  "$common/SteamLinuxRuntime_4/_v2-entry-point" --verb=waitforexitandrun -- \
  "$common/Proton 11.0/proton" waitforexitandrun "$A/Vigilante8PC.exe" \
  > "$out" 2>&1
echo "timeout exit=$?"

# Stop whatever is left of this test (wineserver, the game, the container):
# TERM, give each process up to 10 s, then KILL what remains.
test_pids() {
  for proc in /proc/[0-9]*; do
    if { tr '\0' '\n' < "$proc/environ"; } 2>/dev/null | grep -qx 'V8_BOOT_TEST=1'; then
      echo "${proc#/proc/}"
    fi
  done
}
pids="$(test_pids)"
[ -n "$pids" ] && kill -TERM $pids 2>/dev/null
for pid in $pids; do
  timeout 10 tail --pid="$pid" -f /dev/null 2>/dev/null
done
left="$(test_pids)"
[ -n "$left" ] && kill -KILL $left 2>/dev/null
echo "test processes killed after TERM: $(echo $left | wc -w)"
