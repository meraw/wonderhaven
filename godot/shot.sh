#!/usr/bin/env bash
# Takes a screenshot of the game: ./shot.sh out.png [extra user args, e.g. --pos=0,9,0 --cam=0.3,0.2,4]
cd "$(dirname "$0")"
GODOT="${GODOT:-godot}"
# RENDERER=forward_plus uses the project's default Forward+ renderer (needs Vulkan); the default is the compatibility renderer.
if [ "${RENDERER:-}" = "forward_plus" ]; then rflags="--rendering-method forward_plus --rendering-driver vulkan"; else rflags="--rendering-method gl_compatibility --rendering-driver opengl3"; fi
out="$1"; shift
timeout 240 xvfb-run -a -s "-screen 0 1280x720x24" "$GODOT" --path . $rflags --audio-driver Dummy --resolution 1280x720 -- --shot="$out" "$@" 2>&1 | grep -E "SCRIPT ERROR|ERROR|at:" | grep -v -E "ALSA|audio" | head -20
