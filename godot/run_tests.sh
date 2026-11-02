#!/usr/bin/env bash
# Parse-checks every script, then runs the headless tests. Fails on any script error.
# Usage: GODOT=/path/to/godot ./run_tests.sh
set -u
cd "$(dirname "$0")"
GODOT="${GODOT:-godot}"
"$GODOT" --headless --path . --import >/dev/null 2>&1
fail=0
out=$("$GODOT" --headless --path . -s res://tests/run_tests.gd 2>&1)
echo "$out" | grep -v -E "ALSA|audio_driver|audio drivers|audio_server|^\s*$|Godot Engine"
echo "$out" | grep -qE "SCRIPT ERROR|Failed to load script|Parse Error" && { echo "Script errors during tests"; fail=1; }
echo "$out" | grep -qE "^[0-9]+ passed, 0 failed" || fail=1
exit $fail
