#!/usr/bin/env bash
# Renders the fixed look-dev views, to compare a change to light, colour or materials before and after:
#   ./views.sh <out_dir> [view numbers, e.g. 01,04,06]
# One at a time (several xvfb-run -a at once race for a display), in Forward+ on software Vulkan (needs
# mesa-vulkan-drivers on a headless Linux machine); RENDERER=compat uses the compatibility renderer. About a minute
# a view in software. Measure the results with measure_views.py (brightness, contrast, clipping, saturation).
cd "$(dirname "$0")"
GODOT="${GODOT:-godot}"
out="$1"; only="${2:-}"
[ -n "$out" ] || { echo "usage: ./views.sh <out_dir> [01,04,...]"; exit 1; }
mkdir -p "$out"; out="$(cd "$out" && pwd)"
if [ "${RENDERER:-}" = "compat" ]; then rflags="--rendering-method gl_compatibility --rendering-driver opengl3"; else rflags="--rendering-method forward_plus --rendering-driver vulkan"; fi
"$GODOT" --headless --path . --import >/dev/null 2>&1
V=(
	"01-piazza-morning|--pos=-2,6,3.14 --cam=3.14,0.35,12 --time=9 --weather=clear"
	"02-wide-noon|--pos=0,0,0 --cam=0.6,0.75,45 --time=12.5 --weather=clear"
	"03-cottage-close|--pos=6,-3,3.14 --cam=2.2,0.3,11 --time=11 --weather=clear"
	"04-golden-hour|--pos=-2,6,0 --cam=-0.9,0.3,16 --time=18.3 --weather=clear"
	"05-sunset-backlight|--pos=-2,6,0 --cam=-0.6,0.12,10 --time=19.5 --weather=clear"
	"06-night|--pos=-2,6,3.14 --cam=3.14,0.4,14 --time=22.5 --weather=clear"
	"07-rain|--pos=-2,6,3.14 --cam=2.4,0.35,14 --time=14 --weather=rain"
	"08-dawn-mist|--pos=31,-5,0 --cam=1.2,0.25,22 --time=6.6 --weather=mist"
	"09-character|--pos=-38,5,1.57 --cam=-1.2,0.12,3.6 --time=10.5 --weather=clear"
	"10-boccapioppo|--island=river_town --cam=0.8,0.55,30 --time=12 --weather=clear"
)
for v in "${V[@]}"; do
	name="${v%%|*}"; args="${v#*|}"
	if [ -n "$only" ] && [[ ",$only," != *",${name:0:2},"* ]]; then continue; fi
	data=$(mktemp -d)   # its own user:// folder, so no save or setting of yours changes the picture
	XDG_DATA_HOME="$data" timeout 300 xvfb-run -a -s "-screen 0 1280x720x24" "$GODOT" --path . $rflags --audio-driver Dummy --resolution 1280x720 -- --shot="$out/$name.png" --skiptitle --frames=20 $args > "$out/$name.log" 2>&1
	rm -rf "$data"
	[ -f "$out/$name.png" ] && echo "ok $name" || echo "MISSING $name (see $out/$name.log)"
done
