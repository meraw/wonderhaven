#!/usr/bin/env bash
# Runs several scripted playthroughs at once and prints a summary.
#   ./play_all.sh [out_root] [name ...]
# With no names: Monteforchetta's (play_full then play_full2, one after the other since part two loads part one's
# save, beside the short ones). Name others to run just those, e.g. ./play_all.sh /tmp/plays play_shop play_sleep, or
# a location's, e.g. ./play_all.sh /tmp/plays play_river_town (it starts there: --island=<id>, plus the arguments on
# its "## Run:" line). JOBS=n runs n at once (default: the number of CPUs).
# Each run has its own user:// folder (saves, settings), so runs at once never share a save slot; play_full2 shares
# play_full's. Screenshots and the log of each run go to <out_root>/<name>/ and <out_root>/<name>.log.
cd "$(dirname "$0")"
GODOT="${GODOT:-godot}"
root="${1:-/tmp/wonderhaven-plays}"; shift || true
mkdir -p "$root"; root="$(cd "$root" && pwd)"
if [ $# -gt 0 ]; then lanes=("$@")
else lanes=("play_full,play_full2" play_cove play_camera play_interiors play_shop play_sleep play_build play_build_clarity play_needs play_story play_tutorial play_core play_dialogue play_overlays play_map play_ui_shots play_load_away); fi
JOBS="${JOBS:-$(nproc)}"

# The extra arguments and TIMEOUT a playthrough asks for on its "## Run:" line, and --island=<id> for a location's.
args_for() {
	local name="$1" line id
	line=$(grep -m1 "^## Run:" "tests/$name.gd" 2>/dev/null | sed 's/(.*//')
	id="${name#play_}"
	[ -d "data/locations/$id" ] && [[ "$line" != *--island=* ]] && echo -n "--island=$id "
	for t in $line; do [[ "$t" == --* ]] && echo -n "$t "; done
}
timeout_for() { grep -m1 "^## Run:" "tests/$1.gd" 2>/dev/null | grep -o "TIMEOUT=[0-9]*" | cut -d= -f2; }

run_one() {   # name, user-data folder
	local name="$1" t0=$SECONDS code
	TIMEOUT="${TIMEOUT:-$(timeout_for "$name")}" SKIP_IMPORT=1 XDG_DATA_HOME="$2" \
		./play.sh "res://tests/$name.gd" "$root/$name" $(args_for "$name") > "$root/$name.log" 2>&1
	code=$?
	echo "$code $((SECONDS - t0))" > "$root/$name.result"
	echo "  finished $name: exit $code in $((SECONDS - t0)) s"
	return $code
}

run_lane() {   # comma-separated names, one after the other, sharing saves; stops at the first that fails
	local data="$root/.userdata/${1//,/+}"
	rm -rf "$data"; mkdir -p "$data"
	IFS=',' read -ra names <<< "$1"
	for n in "${names[@]}"; do run_one "$n" "$data" || break; done
}

echo "Importing once for all runs..."
"$GODOT" --headless --path . --import >/dev/null 2>&1
for lane in "${lanes[@]}"; do IFS=',' read -ra ns <<< "$lane"; for n in "${ns[@]}"; do rm -f "$root/$n.result"; done; done
t_all=$SECONDS
echo "Playing ${#lanes[@]} lane(s), $JOBS at a time; logs in $root"
for lane in "${lanes[@]}"; do
	while [ "$(jobs -rp | wc -l)" -ge "$JOBS" ]; do wait -n; done
	echo "  started ${lane//,/ then }"
	run_lane "$lane" &
done
wait

fails=0
echo
echo "Summary ($((SECONDS - t_all)) s in all):"
for lane in "${lanes[@]}"; do
	IFS=',' read -ra ns <<< "$lane"
	for n in "${ns[@]}"; do
		if [ ! -f "$root/$n.result" ]; then printf "  %-20s not run (an earlier part failed)\n" "$n"; fails=1; continue; fi
		read -r code secs < "$root/$n.result"
		done_line=$(grep -m1 "AUTOPLAY DONE" "$root/$n.log" || grep -m1 "AUTOPLAY TIMEOUT" "$root/$n.log" || echo "no result (exit $code)")
		printf "  %-20s %-4s %5s s  %s\n" "$n" "$([ "$code" = 0 ] && echo ok || echo FAIL)" "$secs" "$done_line"
		if [ "$code" != 0 ]; then fails=1; grep "^FAIL " "$root/$n.log" | sed 's/^/      /'; fi
	done
done
exit $fails
