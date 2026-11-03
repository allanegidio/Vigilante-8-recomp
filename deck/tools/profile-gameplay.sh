#!/bin/bash
# Record a .NET EventPipe CPU sample profile of normal gameplay (no soak) into
# ~/.cache/v8-staging/v8.nettrace. Run it detached, e.g.
#   systemd-run --user --scope --unit=v8-profile --collect /bin/bash profile-gameplay.sh
# Convert on the Mac with dotnet-trace (see deck/README.md).
# usage: profile-gameplay.sh [seconds=260] [probe-gameplay.sh args ...]
set -u
seconds="${1:-260}"
shift || true
rm -f "$HOME/.cache/v8-staging/v8.nettrace"
bash "$HOME/.cache/v8-staging/tools/probe-gameplay.sh" "$seconds" \
  "env:RECOMPONE_V82_SOAK=0" \
  "env:RECOMPONE_WINDOW_MAX_PRESENTS=6500" \
  "env:DOTNET_EnableEventPipe=1" \
  'env:DOTNET_EventPipeOutputPath=Z:\home\deck\.cache\v8-staging\v8.nettrace' \
  "env:DOTNET_EventPipeConfig=Microsoft-DotNETCore-SampleProfiler:0:5,Microsoft-Windows-DotNETRuntime:0x4c14fccbd:5" \
  "env:DOTNET_EventPipeCircularMB=1024" \
  "$@"
