#!/bin/bash
# Copy the exe built by ./v8build.sh publish to the Deck install (run on the Mac).
# The first deploy keeps the official exe as Vigilante8PC.exe.v1.0-official;
# later ones keep the previous build as Vigilante8PC.exe.prev.
# usage: deck/deploy-exe.sh [ssh host=steamdeck]
set -euo pipefail
cd "$(dirname "$0")/.."
host="${1:-steamdeck}"
exe=artifacts/publish/Vigilante82PC.exe
shasum -a 256 "$exe"
scp -q "$exe" "$host:.cache/v8-staging/Vigilante8PC-main.exe"
ssh -o BatchMode=yes "$host" 'set -e
A="$HOME/Games/Quiver Launcher/Apps/Vigilante8Classic"
if pgrep -x reaper > /dev/null || pgrep -x Vigilante8PC.ex > /dev/null; then
  echo "a game is running; abort"; exit 1
fi
if [ -e "$A/Vigilante8PC.exe.v1.0-official" ]; then
  cp -p "$A/Vigilante8PC.exe" "$A/Vigilante8PC.exe.prev"
else
  mv "$A/Vigilante8PC.exe" "$A/Vigilante8PC.exe.v1.0-official"
fi
cp ~/.cache/v8-staging/Vigilante8PC-main.exe "$A/Vigilante8PC.exe"
sha256sum "$A"/Vigilante8PC.exe*'
