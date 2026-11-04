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
| Stuck somewhere? | Esc → 🆘 I'm stuck (back to the inn) | Start |
| Menu / back | Esc | Start |
| Fullscreen | F11 or Alt+Enter (also in Settings) | — |
| Build: place / select · cancel | Left click · right click | — |
| Build: rotate · colour · move · remove | R · T · N · Delete | RB · — · — · LB |
| Build: undo · redo · half-grid | Ctrl+Z · Ctrl+Y · G | — |

All keys can be changed in **Menu → Settings & controls**. On a gamepad, build mode uses the right stick as a cursor, D-pad left/right to pick a piece, D-pad up/down to change category, A to place or select and B to cancel.

## For developers
- Content lives in `data/*.json` and is edited directly: layout (buildings, rooms and their furniture, zones, nodes), pieces, villagers, quests (staged requests), shops, Harmony unlocks, the guided first day (`tutorial.json`). The browser version in the repo root is frozen; `npm run godot:data` would overwrite this folder from it and refuses without `--force`.
- Rules are plain GDScript in `scripts/systems/` and are covered by headless tests: `GODOT=/path/to/godot ./run_tests.sh`.
- Scripted playthroughs send real key and mouse events to the running game: `GODOT=... ./play.sh res://tests/play_full.gd /tmp/out`, then `play_full2.gd` (it loads the slot-3 save part one makes). Needs `xvfb-run` on a headless Linux machine. Quicker focused runs: `play_core`, `play_build`, `play_story`, `play_tutorial`, `play_dialogue`, `play_camera`, `play_overlays`, `play_interiors`, `play_shop`.
- Character look-dev renders: `GODOT=... ./lookdev.sh out.png --view=lineup|close|faces`.
- Screenshots: `GODOT=... ./shot.sh out.png --pos=0,9,0 --cam=0.3,0.2,3.5 --time=19` (compatibility renderer; add `RENDERER=forward_plus` to see the game as it normally renders, with SSAO, glow and soft shadows).

### Data cheat sheet
- **Islands:** `islands.json` lists them; an island with a `layout_<id>.json` can be sailed to. A layout has `spawn` (new game), `arrive` (where the ferry lands), buildings, zones, nodes, features (a `boat`), nav graph, paths, `machines`, `props` and `decor`. Give its villagers `"island": "<id>"` in `npcs.json`; their requests belong to that island. The ground shape is a function in `scripts/systems/heightfield.gd`. Start on an island for screenshots with `--island=<id>`.
- **Rooms you can walk into:** give a building in `layout.json` an `interior` block: `shell` (`house` or `castle`), `items` (`[id, x, z, quarter-turns, colour?]`, build pieces or props: oven, barrel, crate, throne, banner, pillar), `route` (nav path from the door to where the owner works), `empty: true` for a room someone wants help with. Collision, the fading roof, the indoor camera and villager routes all follow from it.
- **Requests (`quests.json`):** objectives can have a `stage`; only the lowest unfinished stage is active. Kinds: `gather`, `event`, `build` (a live check), `room` (a checklist in a build zone), `pieces` (a count of pieces in a zone), `harmony`, `flag`, `pay` (hand coins or items to a villager), `talk` (`final` ones hand the request in; others are a step, with optional `lines`). `onDone` on an objective grants flags, items or blueprints when it completes.
- **Shops (`shops.json`):** per villager: `buys` (coins per item), `stock` (item bundles, blueprints or clothes for coins), `requires` for the shop or a line. Gift preferences are `likes` in `npcs.json`; treats carry a `treat` value in `resources.json`.
