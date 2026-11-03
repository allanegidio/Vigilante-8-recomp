# Steam Deck kit

Everything used to install, configure, build, test and profile this recomp on Allan's
Steam Deck (SteamOS 3.9, Proton 11.0, Quiver Launcher v3.5.1). It started on 2026-11-02.

- `tools/` lives on the Deck in `~/.cache/v8-staging/tools`. To update it:
  `scp -r deck/tools steamdeck:.cache/v8-staging/`
- `install/` holds the one-time scripts used for the first install, kept for the record.
- `profiling/` holds the Mac-side scripts that read profiles.
- `results/` holds the measurements.
- `deploy-exe.sh` runs on the Mac.

Never commit disc data or anything derived from it. That covers `V8_2_BINCUE/`,
`V8_2_WORK/`, `reference-v8-2/generated/`, `artifacts/`, `game_data/` and the `.ogg`
music. `.gitignore` already covers what lives in this checkout.

## What is on the Deck

- Install folder: `~/Games/Quiver Launcher/Apps/Vigilante8Classic/`.
  - `Vigilante8PC.exe` is our build of main. See *Building* below.
  - `Vigilante8PC.exe.v1.0-official` is the official v1.0 exe.
  - `game_data/` holds the extracted 2nd Offense disc, plus `music/` from the V8 disc.
  - `mods/` holds the five bundled mods.
  - The profile files sit next to the exe: `settings.json`, `interface.ini`,
    `carda.sav`/`cardb.sav` and `v8_latest.log`.
  - Quiver's markers are `version.txt` (the exact release tag) and `installed-build.txt`
    (the asset name, then the zip's sha256).
- Discs: `~/Games/Vigilante 8 - 2nd Offense/` (BIN/CUE, USA, SLUS-00868) and
  `~/Games/Vigilante 8/` (V8 USA, used only for its music).
- Steam shortcut "Vigilante 8 2nd Offense" (appid 3982178090):
  - Proton 11 is forced through `config.vdf` CompatToolMapping.
  - Launch options:
    `RECOMPONE_DIRECT_TERRAIN=1 DOTNET_GCgen0size=0x10000000 /home/deck/.local/bin/v8-cpu-performance %command%`.
  - `v8-cpu-performance` (from `tools/`) switches the CPU governor to "performance"
    while the game runs and restores the previous one when it exits.
  - **Play from Steam.** Quiver's Play button doesn't pass the launch options.
- One game has everything: the 2nd Offense engine with the 12 V8 drivers as guests (quests
  and endings), the V8 arenas, Super Dreamland 64 and both soundtracks.
- Test files live in `~/.cache/v8-staging/`: `tools/`, `probe/` (the last test profile),
  `prefix/` (the tests' own Wine prefix) and `results.txt`.

## Install from scratch

1. **Quiver.** Close Quiver, then run `install/quiver_add_app.py <apps.json> install/quiver-entry.json`.
   - The entry tracks GTTeancum/Vigilante-8-recomp with auto-update, and runs with Proton 11.0.
   - Unzip the release into `Apps/Vigilante8Classic`, flattened.
   - Write `version.txt` (the tag) and `installed-build.txt` (the asset name, then the zip
     sha256), so Quiver sees the app as installed and offers updates.
2. **Disc.** Run `tools/extract-disc.sh`. It is the game's headless `--extract-loose`; the
   setup window's BIN/CUE picker crashes (upstream issue #3).
3. **V8 soundtrack.** Run `tools/encode-v8-music.sh`.
4. **settings.json.** Set these keys:
   - `ActiveMods`: `enhanced_textures_2x`, `ttf_game_font`, `v82_n64_super_dreamland`,
     `v8_to_v82_guest_roster`. `v8_classic_menu` stays off, which keeps the 2nd Offense
     menus.
   - `ModsVersion`: 1.
   - `Soundtrack`: 2 (both).
5. **Graphics.** Let the game write `interface.ini` first. A boot with
   `RECOMPONE_WINDOW_MAX_PRESENTS=240` exits cleanly and saves it. Then run
   `tools/ini_patch.py interface.ini tools/values.ini`.
   - A file without the ImGui layout section leaves the game in a floating 640x480
     "Output" window.
   - Keep `GraphicsPreset=Custom`. "Enhanced" re-applies its own values on every start.
6. **Steam.** With Steam stopped, run `install/steam-apply.sh`. It writes the shortcut and
   the forced Proton 11 with `tools/steam_vdf.py`.
   - Use `tools/steam-set-options.sh "<name>" "<options>"` to change the launch options.
   - Both scripts stop and restart Steam. Game Mode uses
     `systemctl --user stop/start steam-launcher.service`; Desktop Mode uses
     `steam -shutdown` and a relaunch.
   - History: there were two shortcuts at first. `install/unify.sh` merged them into one
     and removed the second profile.

## Building the exe (on the Mac)

- **Why build at all.** The official v1.0 HD shader uses 20 vertex attributes, and Mesa
  allows 16. The link fails (`[GlBackend] link failed (prim) ... location 16`) and the game
  falls back to the 320x240 software renderer. PR #7 (merged into main, not released yet)
  cuts the shader to 14 attributes.
- **Needs:** the .NET 10 SDK in `~/.dotnet`, Python 3, and the disc's track 01 in
  `V8_2_BINCUE/`.
- **Build:** `./v8build.sh all`, or a single step: `extract`, `prepare`, `recompiler`,
  `generate` or `publish`. The output is `artifacts/publish/Vigilante82PC.exe`.
- **Deploy:** `deck/deploy-exe.sh` (the host defaults to `steamdeck`, or pass
  `steamdeck-ip`). It aborts while a game is running and keeps the previous exe.
- **Updates.** Quiver tracks the official releases. The next official release replaces our
  exe, and that is fine once it includes PR #7. Anything of ours that isn't upstream yet
  must then be rebuilt and deployed again.

## Performance

The game clock runs at a fixed 60 emulated frames per second (`Host/FrameClock.cs`).
Any frame over 16.7 ms plays in slow motion; there is no frame skip.

What we found (EventPipe profiles, 2026-11-03; the main thread is the limit). The numbers
come from the soak profile taken with both launch env vars on:

| Cost on the main thread | Cause | Status |
| --- | --- | --- |
| 31% | `ReadTerrainCellTextures` > `ReadDreamcastTerrainDistanceColors` (24%) | Open. The terrain cache runs only in 4-player mode (`BeginSharedTerrainFrame`). |
| 26% | Edge-pool `ReadVram` GPU readback stall (LOD Maximum) | Open |
| ~20% | `Thread.PollGC` waits | Mostly the profiler's own cost: EventPipe suspends the runtime every 1 ms, which is slow under Wine. Real GCs are rare (`gc=` in `[EnhancedPerformance]`). `DOTNET_GCgen0size=0x10000000` makes them rarer still. |

Single player never turned on the developer's 4-player "direct scene" optimizations.
`RECOMPONE_DIRECT_TERRAIN=1` turns them on. Normal play went from about 51-53 fps to
59.5 average (52 minimum). `results/measurements-2026-11-03.txt` has every run.

The biggest lever is the CPU governor (2026-11-03). SteamOS's default "powersave"
governor (amd-pstate, EPP balance_performance) keeps the cores near 2.4 GHz and about
6 W, because the main thread is never 100% busy: it waits on the GPU readback and the
frame clock. `steamosctl set-cpu-scaling-governor performance` needs no root, and with it
the cores boost to 3.5 GHz at about 10.5 W. Same build, 60-present windows below 55 fps:

| Run | powersave | performance |
| --- | --- | --- |
| Route 66 soak (heavy fight) | 30 of 90, 55.8 fps average | 6 of 128, 58.9 average; last 40 s 60.0 (min 58.9) |
| Casino City, normal play | 26 of 120, 56.8 average | 6 of 127, 58.9 average; last 40 s 60.0 (min 59.5) |

Under "performance" the main thread uses about 60% instead of 80%, so there is headroom.
The Steam launch wrapper `tools/v8-cpu-performance` applies it only while the game runs.

Things that didn't help:

- MSAA 2x instead of 4x, or anisotropic filtering 8x: within the noise.
- Mesa `glthread`: no change.
- Zink: about 15 fps.
- LOD Stock: 13 fps, pathological. Keep Maximum.

### Measuring and profiling

- `tools/measure.sh <label> [KEY=VALUE ...] [env:NAME=VALUE ...]` drives the game into a
  match with the project's soak input in a throwaway profile, then appends fps, CPU, GPU
  and power to `results.txt`. Pass `env:RECOMPONE_V82_SOAK=0` for normal play; the soak
  fires weapons and power-ups as a stress load.
- `tools/profile-gameplay.sh` records `~/.cache/v8-staging/v8.nettrace`. Convert it on the
  Mac with
  `dotnet-trace convert --format speedscope v8.nettrace -o v8`, then run
  `python3 -I deck/profiling/speedscope_hot.py v8.speedscope.json` (hot spots per thread)
  or `speedscope_stacks.py` (top stack tails).
- `tools/probe-gameplay.sh` is the driver under both. It sets the same env as the Steam
  shortcut, and `env:` args override it.

### Weapon and car tests

- `tools/weapon-sweep.sh [types ...]` runs one silent, hidden, unthrottled match per car
  (default: retail 0-17 and guests 64-76, about 2 minutes each). The soak arms each
  weapon kind in turn (1 rockets, 2 missiles, 3 cannon, 4 mortar, 5 mines,
  6 flamethrower, 7 special), the script fires L2 three times per kind and captures
  frames, and each run lands in `~/.cache/v8-staging/sweep/<type>/`.
- `python3 -I deck/profiling/sweep_report.py <dir>` turns the logs into one row per car.
  It shows whether each kind armed and fired, and whether the special is the engine's
  placeholder (`0x80049880`: it only spends ammo).
- `tools/weapon-view.sh <label> [kind] [type] [arena slot]` fires one weapon from a held
  scene and captures 1.5 s of it. With `V8_TEST_EXE=<exe beside the installed one>`
  (also honoured by `v8-boot-test.sh`), it runs another build for an A/B comparison.
- `python3 -I deck/profiling/ppm_to_png.py --half <file.ppm> ...` converts captures to
  PNG.
- Two runs of the same input don't play out identically, so compare looks with
  `weapon-view.sh`, not with sweep captures.

## Testing over SSH

- Tests must be silent, because Allan may be next to the Deck. `v8-boot-test.sh` sets
  `SDL_AUDIODRIVER=dummy` and `RECOMPONE_MUTE=1`. `steam-launch-test.sh` starts the real
  game with sound, so ask first.
- SteamOS sets `KillUserProcesses=True`. A job that must outlive the SSH session needs
  `systemd-run --user --scope`.
- A plain `systemd-run` unit can't see the X socket. The scripts take `DISPLAY` and
  `XAUTHORITY` from the running steam process.
- polkit denies `systemd-inhibit` over SSH, so turn sleep off on the Deck during long tests.
- Inside `ssh '<script>'`, `pgrep -f` matches the script's own command line. Use
  `pgrep -x reaper` or `pgrep -x Vigilante8PC.ex`.
- mDNS (`steamdeck.local`) is flaky; `steamdeck-ip` in `~/.ssh/config` is the fallback.
- FMVs and the long intro run at 15 fps. That is the PS1 STR rate, not a problem.

## Open issues (2026-11-03)

- Specials of 11 V8 guests: the special spends ammo but nothing comes out. They are
  Chassey Blue, Slick Clyde, Sheila, John Torque, Dave, Convoy, Loki, Boogie, Beezwax,
  Molo and Sid Burn.
  - Upstream never ported them. They get V8:2's placeholder callback `0x80049880`, and
    only Houston 3 and "Y" have original ports (`sdk/V8OriginalSpecials.cs`).
  - The weapon sweep of all 31 cars confirmed it: every other weapon arms and fires on
    every car, and the 18 retail specials are real.
  - Porting a special needs the original V8 code. `./v8build.sh v8-prepare` and
    `v8-generate` recompile Allan's V8 disc (in `BINCUE/`, git-ignored) into
    `reference/generated/recompiled/main.cs`.
- FIXED (11-03): the mortar shell was almost invisible; only a small purple streak
  showed.
  - Cause: with EnhancedParticles on, the HD shader dimmed additive effects through a
    coverage gate measured in each triangle's UV box. The shell is a 4-triangle fan, so
    it lost about 90% of its light.
  - `GlShaders.cs` now keeps the light of world additive effects. Vehicle parts keep the
    old gate. Texels under 24/255 are dropped and the rim fades in, which keeps the
    depth/stencil footprint near the old one: kept fragments make the deferred roads,
    water and weather skip those pixels.
  - Distance fog now fades added light instead of tinting it.
  - `weapon-view.sh` A/B: the shell's magenta column is back, and no ground holes showed
    in the captures. Not checked yet: a road or water scene under explosions.
- FIXED (11-03): heavy fights dipped to about 42-46 fps (Casino City), 55 average.
  - Main fix: the CPU governor wrapper (see *Performance*). Heavy fights now hold about
    59-60 fps.
  - The shared terrain cache now also runs in single player (hooks on `func_80031678`).
    `RECOMPONE_V82_SINGLE_PLAYER_TERRAIN_CACHE=0` turns it off for A/B runs, and
    `RECOMPONE_VERIFY_SHARED_TERRAIN=1` checks every cache hit against a full read.
  - The verification found 0 mismatches in about 1 million hits (Route 66 and Casino City).
  - It brought no measurable fps gain. Route 66 measured 58.7 vs 59.1 fps, the soak
    56.0 vs 56.0 and Casino City 58.1 vs 57.7, so the profile's 31% for terrain reads
    was mostly EventPipe sampling cost.
  - Proton also starts `xalia.exe`, about 9% of a core, which this game doesn't need.
    Not changed yet.
