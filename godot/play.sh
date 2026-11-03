#!/usr/bin/env bash
# Runs a scripted playthrough with a real (virtual) display: ./play.sh res://tests/play_core.gd /tmp/out
cd "$(dirname "$0")"
GODOT="${GODOT:-godot}"
script="$1"; out="${2:-/tmp/wonderhaven-play}"
# RENDERER=forward_plus plays with the game's normal renderer (needs Vulkan); the default is the compatibility renderer.
if [ "${RENDERER:-}" = "forward_plus" ]; then rflags="--rendering-method forward_plus --rendering-driver vulkan"; else rflags="--rendering-method gl_compatibility --rendering-driver opengl3"; fi
mkdir -p "$out"
"$GODOT" --headless --path . --import >/dev/null 2>&1
timeout "${TIMEOUT:-600}" xvfb-run -a -s "-screen 0 1280x720x24" "$GODOT" --path . $rflags --resolution 1280x720 -- --autoplay="$script" --out="$out" $( [[ "$script" == *play_full* ]] && echo --title --limit=2300 ) 2>&1 | grep -v -E "ALSA|audio|vsync|ERR_CANT_OPEN|^\s*$|at: (init_output|initialize|set_use)"
exit ${PIPESTATUS[0]}
