#!/bin/bash
# Encode the first game's soundtrack from Allan's Vigilante 8 (USA) disc into
# game_data/music: audio tracks 2-13 from INDEX 01 (his cue has a 2 s pregap,
# 352800 bytes), libvorbis q6, named as V8LooseManifest.json expects.
# settings.json "Soundtrack" picks 0 = V8, 1 = 2nd Offense, 2 = both.
# usage: encode-v8-music.sh [disc folder] [output folder]
set -eu
src="${1:-$HOME/Games/Vigilante 8}"
out="${2:-$HOME/Games/Quiver Launcher/Apps/Vigilante8Classic/game_data/music}"
mkdir -p "$out"
n=2
for name in BOOGIE BEEZEWAX CONVOY DAVE HOUSTON3 JOHNT LOKI MOLO SHELIA SID SLICK CHASSEY; do
  track="$(printf %02d "$n")"
  ffmpeg -nostdin -hide_banner -loglevel error -y \
    -f s16le -ar 44100 -ac 2 -skip_initial_bytes 352800 \
    -i "$src/Vigilante 8 (USA) (v1.0) (Track $track).bin" \
    -c:a libvorbis -q:a 6 -metadata TITLE="Vigilante 8 Track $track ($name)" \
    "$out/$name.ogg"
  n=$((n + 1))
done
ls -la "$out"
