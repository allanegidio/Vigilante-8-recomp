#!/bin/bash
# Keep only the "Vigilante 8 2nd Offense" shortcut: the default profile beside
# the exe, every bundled mod except the V8 Classic menu skin, both soundtracks.
set -u
tools="$HOME/.cache/v8-staging/tools"
A="$HOME/Games/Quiver Launcher/Apps/Vigilante8Classic"
P="$A/2nd-offense-profile"
steam_root="$HOME/.local/share/Steam"
shortcuts="$steam_root/userdata/84908674/config/shortcuts.vdf"
stamp="$(date +%Y%m%d-%H%M%S)"

if pgrep -x reaper > /dev/null || pgrep -x Vigilante8PC.ex > /dev/null; then
  echo "a game is running; abort"; exit 1
fi

# 1. Default profile: all mods but the menu skin, both soundtracks.
cp -p "$A/settings.json" "$A/settings.json.bak-$stamp"
cd "$HOME" && python3 -I - "$A/settings.json" <<'EOF'
import json
import sys
path = sys.argv[1]
settings = json.load(open(path, encoding="utf-8-sig"))
settings["ActiveMods"] = ["enhanced_textures_2x", "ttf_game_font",
                          "v82_n64_super_dreamland", "v8_to_v82_guest_roster"]
settings["ModsVersion"] = max(1, settings.get("ModsVersion", 0))
settings["Soundtrack"] = 2
with open(path, "w", encoding="utf-8") as handle:
    json.dump(settings, handle, indent=2)
print("settings:", settings["ActiveMods"], "soundtrack:", settings["Soundtrack"])
EOF

# 2. Keep the newer quest progress of the two profiles.
if [ -f "$P/quest-progress.json" ] && ! cmp -s "$P/quest-progress.json" "$A/game_data/quest-progress.json"; then
  if [ "$P/quest-progress.json" -nt "$A/game_data/quest-progress.json" ]; then
    cp -p "$A/game_data/quest-progress.json" "$A/game_data/quest-progress.json.bak-$stamp"
    cp -p "$P/quest-progress.json" "$A/game_data/quest-progress.json"
    echo "quest progress: took the 2nd Offense profile's (newer)"
  fi
else
  echo "quest progress: identical, nothing to move"
fi

# 3. Steam: stop it, drop the "Vigilante 8" shortcut, clear the wrapper option.
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
cp -p "$shortcuts" "$shortcuts.bak-before-unify-$stamp"
python3 -I "$tools/steam_vdf.py" edit "$shortcuts" "Vigilante 8" "Vigilante 8 2nd Offense" "" &&
  python3 -I "$tools/steam_vdf.py" list "$shortcuts" | grep -E "round-trip|Vigilante" ||
  { echo "edit failed; restoring"; cp -p "$shortcuts.bak-before-unify-$stamp" "$shortcuts"; }

echo "starting Steam..."
if [ "$game_mode" = yes ]; then
  systemctl --user start steam-launcher.service
else
  # Relaunch the desktop client with its own environment and arguments.
  systemd-run --user --scope --unit="steam-relaunch-$stamp" --collect \
    env -i "${steam_env[@]}" "${steam_cmd[@]}" > /dev/null 2>&1 < /dev/null &
  disown
fi

# 4. Remove what the second profile needed.
rm -rf "$P" "$HOME/.local/bin/vigilante8-steam" "$steam_root/steamapps/compatdata/3217384728"
echo "removed the 2nd Offense profile folder, the wrapper and the old prefix"
