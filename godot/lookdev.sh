#!/usr/bin/env bash
# Look-dev renders of the cast: ./lookdev.sh out.png --view=lineup|faces [--face=bean|painted] [--outline=0|1]
# Uses Forward+ (software Vulkan works); set RENDERER=compat for the compatibility renderer.
cd "$(dirname "$0")"
GODOT="${GODOT:-godot}"
if [ "${RENDERER:-}" = "compat" ]; then rflags="--rendering-method gl_compatibility --rendering-driver opengl3"; else rflags="--rendering-method forward_plus --rendering-driver vulkan"; fi
"$GODOT" --headless --path . --import >/dev/null 2>&1
out="$1"; shift
timeout 240 xvfb-run -a -s "-screen 0 1280x720x24" "$GODOT" --path . $rflags --audio-driver Dummy --resolution 1280x720 -s res://tests/lookdev.gd -- --out="$out" "$@" 2>&1 | grep -E "SCRIPT ERROR|SHADER ERROR|ERROR|error\(" | grep -v -E "ALSA|audio|ERR_CANT_OPEN|resources still|vsync" | head -20
