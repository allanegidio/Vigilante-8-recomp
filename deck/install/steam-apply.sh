#!/bin/bash
# Stop Steam, add the two Vigilante 8 shortcuts with Proton 11 forced, start Steam.
set -u
tools="$HOME/.cache/v8-staging/tools"
steam_root="$HOME/.local/share/Steam"
shortcuts="$steam_root/userdata/84908674/config/shortcuts.vdf"
config="$steam_root/config/config.vdf"
stamp="$(date +%Y%m%d-%H%M%S)"

for proc in /proc/[0-9]*; do
  if { tr '\0' '\n' < "$proc/environ"; } 2>/dev/null | grep -qx 'V8_BOOT_TEST=1'; then
    echo "a boot test is still running; abort"; exit 1
  fi
done
if pgrep -f 'reaper SteamLaunch' > /dev/null; then
  echo "a game is running; abort"; exit 1
fi

echo "stopping steam-launcher..."
systemctl --user stop steam-launcher.service
if pgrep -x steam > /dev/null; then
  echo "steam still running after stop; abort"
  systemctl --user start steam-launcher.service
  exit 1
fi

cp -p "$shortcuts" "$shortcuts.bak-before-vigilante8-$stamp"
cp -p "$config" "$config.bak-before-vigilante8-$stamp"
cd "$HOME"
if python3 -I "$tools/steam_vdf.py" add "$shortcuts" "$config" proton_11 "$tools/steam-shortcuts.json"; then
  python3 -I "$tools/steam_vdf.py" list "$shortcuts"
  grep -n -A20 '"CompatToolMapping"' "$config" | head -24
else
  echo "write failed; restoring backups"
  cp -p "$shortcuts.bak-before-vigilante8-$stamp" "$shortcuts"
  cp -p "$config.bak-before-vigilante8-$stamp" "$config"
fi

echo "starting steam-launcher..."
systemctl --user start steam-launcher.service
systemctl --user is-active steam-launcher.service
