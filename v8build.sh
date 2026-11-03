#!/bin/bash
# Build Vigilante 8 Classic from this checkout (GTTeancum/Vigilante-8-recomp
# main, which has PR #7's Mesa/NVIDIA shader fix) as the win-x64 single-file
# Vigilante8PC.exe, from Allan's own 2nd Offense disc, for the Steam Deck.
#
# usage: v8build.sh extract|prepare|recompiler|generate|publish|all|runtime-check|special-tests
#        v8build.sh v8-prepare|v8-generate
# The v8-* steps recompile the FIRST game (Allan's V8 USA disc in BINCUE/)
# into reference/generated/recompiled/main.cs, only to read its original code
# (the guest specials are ported from it). They build nothing that ships.
set -euo pipefail
cd "$(dirname "$0")"

export DOTNET_ROOT="$HOME/.dotnet"
export PATH="$HOME/.dotnet:$PATH"
export DOTNET_CLI_TELEMETRY_OPTOUT=1
export DOTNET_NOLOGO=1

bin="V8_2_BINCUE/Vigilante 8 - 2nd Offense (USA) (Track 01).bin"
v8cue="BINCUE/Vigilante 8 (USA) (v1.0).cue"

step_extract() {
  python3 tools/extract_psx_iso.py "$bin" V8_2_WORK/disc --clean
}

step_prepare() {
  python3 tools/recompone-v8-2/prepare_reference.py --loose-disc V8_2_WORK/disc
}

step_recompiler() {
  dotnet build tools/recompone-reference/RecompOne.Recompiler/RecompOne.Recompiler.csproj -c Release
}

step_generate() {
  dotnet tools/recompone-reference/RecompOne.Recompiler/bin/Release/net10.0/recompone.dll \
    reference-v8-2/generated/v82.recompone.json
}

step_publish() {
  # The build patches main.cs in place (apply_vehicle_engine_patches.py) and
  # fails on an already patched file, so every publish starts from a fresh one.
  step_generate
  # The project uses Windows path separators; MSBuild on macOS converts some
  # of them but not "$(MSBuildProjectDirectory)\main.cs" in Exec commands.
  # prepare_reference.py copies this file fresh, so fix the copy only.
  sed -i '' 's#\\#/#g' reference-v8-2/generated/recompiled/Vigilante82PC.csproj
  dotnet publish reference-v8-2/generated/recompiled/Vigilante82PC.csproj \
    -c Release -p:PythonExe=python3 -o artifacts/publish
}

step_v8_prepare() {
  python3 tools/recompone-v8/prepare_reference.py --cue "$v8cue" --skip-dreamland
}

step_v8_generate() {
  dotnet tools/recompone-reference/RecompOne.Recompiler/bin/Release/net10.0/recompone.dll \
    reference/generated/v8.recompone.json
}

step_runtime_check() {
  dotnet build tools/recompone-reference/RecompOne.Runtime/RecompOne.Runtime.csproj -c Release -v q -nologo
}

step_special_tests() {
  dotnet run --project tools/recompone-v8-2/tests/SpecialResourceContract/SpecialResourceContract.csproj -c Release
}

case "${1:-}" in
  extract | prepare | recompiler | generate | publish) "step_$1" ;;
  v8-prepare) step_v8_prepare ;;
  v8-generate) step_v8_generate ;;
  runtime-check) step_runtime_check ;;
  special-tests) step_special_tests ;;
  all)
    step_extract
    step_prepare
    step_recompiler
    step_generate
    step_publish
    ;;
  *)
    echo "usage: $0 extract|prepare|recompiler|generate|publish|all|v8-prepare|v8-generate|runtime-check|special-tests" >&2
    exit 64
    ;;
esac
