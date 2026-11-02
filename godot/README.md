# Wonderhaven — Godot 4 version

## Open and play
1. Install **Godot 4.4 or newer**, the standard edition (not .NET): https://godotengine.org/download
2. Start Godot → **Import** → choose `godot/project.godot` from this repository → **Import & Edit**.
3. Press **F5** (or the ▶ button, top right) to play.

Controls: WASD move · Shift run · right-drag or Q/Z turn camera · wheel zoom · E interact · Space hop. A gamepad works too.

## For developers
- Content (layout, pieces, villagers, quests, unlocks) lives in `data/*.json`, generated from the shared content files by `npm run godot:data` (repo root).
- Rules are plain GDScript in `scripts/systems/` and are covered by headless tests: `GODOT=/path/to/godot ./run_tests.sh`.
- Scripted playthroughs send real key/mouse events to the running game: `GODOT=... ./play.sh res://tests/play_core.gd /tmp/out` (needs `xvfb-run` on a headless machine).
- Screenshots: `GODOT=... ./shot.sh out.png --pos=0,9,0 --cam=0.3,0.2,3.5`.
