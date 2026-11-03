#!/bin/bash
# Build Vigilante 8 Classic from this checkout (GTTeancum/Vigilante-8-recomp
# main, which has PR #7's Mesa/NVIDIA shader fix) as the win-x64 single-file
# Vigilante8PC.exe, from Allan's own 2nd Offense disc, for the Steam Deck.
#
# usage: v8build.sh extract|prepare|recompiler|generate|publish|all
set -euo pipefail
cd "$(dirname "$0")"

export DOTNET_ROOT="$HOME/.dotnet"
export PATH="$HOME/.dotnet:$PATH"
export DOTNET_CLI_TELEMETRY_OPTOUT=1
export DOTNET_NOLOGO=1

bin="V8_2_BINCUE/Vigilante 8 - 2nd Offense (USA) (Track 01).bin"

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
  # The project uses Windows path separators; MSBuild on macOS converts some
  # of them but not "$(MSBuildProjectDirectory)\main.cs" in Exec commands.
  # prepare_reference.py copies this file fresh, so fix the copy only.
  sed -i '' 's#\\#/#g' reference-v8-2/generated/recompiled/Vigilante82PC.csproj
  dotnet publish reference-v8-2/generated/recompiled/Vigilante82PC.csproj \
    -c Release -p:PythonExe=python3 -o artifacts/publish
}

case "${1:-}" in
  extract | prepare | recompiler | generate | publish) "step_$1" ;;
  all)
    step_extract
    step_prepare
    step_recompiler
    step_generate
    step_publish
    ;;
  *)
    echo "usage: $0 extract|prepare|recompiler|generate|publish|all" >&2
    exit 64
    ;;
esac
