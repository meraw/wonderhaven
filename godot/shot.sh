#!/usr/bin/env bash
# Takes a screenshot of the game: ./shot.sh out.png [extra user args, e.g. --pos=0,9,0 --cam=0.3,0.2,4]
cd "$(dirname "$0")"
GODOT="${GODOT:-godot}"
out="$1"; shift
timeout 150 xvfb-run -a -s "-screen 0 1280x720x24" "$GODOT" --path . --rendering-method gl_compatibility --rendering-driver opengl3 --resolution 1280x720 -- --shot="$out" "$@" 2>&1 | grep -E "SCRIPT ERROR|ERROR|at:" | grep -v -E "ALSA|audio" | head -20
