#!/bin/bash
# One gameplay measurement with interface.ini overrides; appends a summary to
# ~/.cache/v8-staging/results.txt. Meant to run detached (setsid nohup), so a
# dropped SSH session or a Deck sleep doesn't leave the game running.
# usage: measure.sh <label> [KEY=VALUE ...]
set -u
label="$1"
shift
tools="$HOME/.cache/v8-staging/tools"
results="$HOME/.cache/v8-staging/results.txt"
bash "$tools/probe-gameplay.sh" 170 "$@" > "$HOME/.cache/v8-staging/measure-last.out" 2>&1
{
  echo "== $label ${*:-(current settings)}"
  bash "$tools/probe-summary.sh" 40
} >> "$results"
