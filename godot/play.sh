#!/usr/bin/env bash
# Runs a scripted playthrough with a real (virtual) display: ./play.sh res://tests/play_core.gd /tmp/out [--island=<id> ...]
# Frames are only drawn for screenshots, and every frame is 0.1 s of game time (--fixed-fps 10, the step the game caps
# a frame at anyway), so a run goes as fast as the game's own work allows. RENDER_ALL=1 draws every frame (to watch or
# record a run). Several at once, with a summary: ./play_all.sh
# Silent (--audio-driver Dummy): a run plays many times faster than real time, and its music would pour out of the
# speakers at that speed, one stream per run.
cd "$(dirname "$0")"
GODOT="${GODOT:-godot}"
script="$1"; out="${2:-/tmp/wonderhaven-play}"
# RENDERER=forward_plus plays with the game's normal renderer (needs Vulkan); the default is the compatibility renderer.
if [ "${RENDERER:-}" = "forward_plus" ]; then rflags="--rendering-method forward_plus --rendering-driver vulkan"; else rflags="--rendering-method gl_compatibility --rendering-driver opengl3"; fi
mkdir -p "$out"
[ -n "${SKIP_IMPORT:-}" ] || "$GODOT" --headless --path . --import >/dev/null 2>&1
timeout "${TIMEOUT:-600}" xvfb-run -a -s "-screen 0 1280x720x24" "$GODOT" --path . $rflags --audio-driver Dummy --resolution 1280x720 --fixed-fps "${FPS:-10}" -- --autoplay="$script" --out="$out" $( [[ "$script" == *play_full* ]] && echo --title --limit=7000 ) "${@:3}" $( [[ "$script" == *play_cove* ]] && echo --limit=7000 ) $( [[ "$script" == *play_camera* ]] && echo --limit=3300 ) 2>&1 | grep -v -E "ALSA|audio|vsync|ERR_CANT_OPEN|^\s*$|at: (init_output|initialize|set_use)"
exit ${PIPESTATUS[0]}
