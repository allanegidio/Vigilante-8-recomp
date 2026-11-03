#!/bin/bash
# Extract the 2nd Offense disc into the install's game_data with the game's own
# headless extractor. The v1.0 setup window's BIN/CUE picker crashes (upstream
# issue #3), so this replaces it.
# usage: extract-disc.sh [cue]
set -u
A="$HOME/Games/Quiver Launcher/Apps/Vigilante8Classic"
cue="${1:-$HOME/Games/Vigilante 8 - 2nd Offense/Vigilante 8 - 2nd Offense (USA).cue}"
common="$HOME/.local/share/Steam/steamapps/common"
export STEAM_COMPAT_CLIENT_INSTALL_PATH="$HOME/.local/share/Steam"
export STEAM_COMPAT_DATA_PATH="$HOME/.cache/v8-staging/prefix"
export WINEDEBUG=-all
unset DISPLAY WAYLAND_DISPLAY
mkdir -p "$STEAM_COMPAT_DATA_PATH"
w() { local p="Z:$1"; printf '%s' "${p//\//\\}"; }

cd "$A" || exit 1
timeout 900 "$common/SteamLinuxRuntime_4/_v2-entry-point" --verb=waitforexitandrun -- \
  "$common/Proton 11.0/proton" waitforexitandrun "$A/Vigilante8PC.exe" \
  --extract-loose "$(w "$cue")" "$(w "$A/game_data")"
echo "exit=$?"
ls "$A/game_data"
