# Wonderhaven — Godot 4 version

## Open and play
1. Install **Godot 4.4 or newer**, the standard edition (not .NET): https://godotengine.org/download
2. Start Godot → **Import** → choose `godot/project.godot` from this repository → **Import & Edit**. (The first import takes a few seconds.)
3. Press **F5** (or the ▶ button, top right) to play. Your saves live in Godot's user folder, so they survive between sessions.

## Controls
| | Keyboard and mouse | Gamepad |
| --- | --- | --- |
| Move / run | WASD / Shift | Left stick |
| Camera | Right-drag (or left-drag while exploring), Q / Z, mouse wheel to zoom | Right stick |
| Interact, talk, advance dialogue | E | A |
| Starforge build mode | B | X |
| Bag · Journal · Map · Harmony · Wardrobe | I · J · M · P · C | D-pad up · Y · Back · D-pad down |
| Menu / back | Esc | Start |
| Build: place / select · cancel | Left click · right click | — |
| Build: rotate · colour · move · remove | R · T · N · Delete | RB · — · — · LB |
| Build: undo · redo · half-grid | Ctrl+Z · Ctrl+Y · G | — |

All keys can be changed in **Menu → Settings & controls**. On a gamepad, build mode uses the right stick as a cursor, D-pad left/right to pick a piece, D-pad up/down to change category, A to place or select and B to cancel.

## For developers
- Content (layout, pieces, villagers, quests, unlocks) lives in `data/*.json`, generated from the shared content files with `npm run godot:data` (repo root). Edit the content in `src/data/` and re-export.
- Rules are plain GDScript in `scripts/systems/` and are covered by headless tests: `GODOT=/path/to/godot ./run_tests.sh`.
- Scripted playthroughs send real key and mouse events to the running game: `GODOT=... ./play.sh res://tests/play_full.gd /tmp/out` (needs `xvfb-run` on a headless Linux machine). `play_core.gd`, `play_build.gd` and `play_story.gd` are quicker focused runs.
- Screenshots: `GODOT=... ./shot.sh out.png --pos=0,9,0 --cam=0.3,0.2,3.5 --time=19` (compatibility renderer; add `RENDERER=forward_plus` to see the game as it normally renders, with SSAO, glow and soft shadows).
