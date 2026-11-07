#!/usr/bin/env bash
# Rebuilds the model lab's .glb files (godot/assets/models/lab) from the Blender scripts. See docs/MODELS.md.
# Usage: BLENDER=/path/to/blender tools/blender/build_lab.sh [--blend <dir>]
set -euo pipefail
cd "$(dirname "$0")/../.."
BLENDER="${BLENDER:-blender}"
out=godot/assets/models/lab
for script in langhe_lane langhe_street sindaco; do
	"$BLENDER" -b --factory-startup -P "tools/blender/$script.py" -- --out "$out" "$@" 2>&1 | grep -E "^exported|^saved|Error|Traceback|line [0-9]+" || true
done
