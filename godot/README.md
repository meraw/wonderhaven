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
- New locations come as packs, so several can be built at once: `data/locations/<id>/` (layout, map entry and look, villagers, requests, shops, materials) and `scripts/locations/<id>.gd` (ground shape, its own buildings, extra scenery). The game merges them in at load. See `docs/WORLD.md` and `docs/LOCATION_PROMPT.md`.
- Scripted playthroughs send real key and mouse events to the running game: `GODOT=... ./play.sh res://tests/play_full.gd /tmp/out`, then `play_full2.gd` (it loads the slot-3 save part one makes). Needs `xvfb-run` on a headless Linux machine. Frames are only drawn for screenshots and every frame is 0.1 s of game time (`--fixed-fps 10`), so a run goes as fast as the game's own work allows; `RENDER_ALL=1` draws every frame, to watch or record one. `GODOT=... ./play_all.sh /tmp/plays` plays Monteforchetta's whole set (part one then part two, beside the short ones) several at a time, each with its own saves, and prints a summary; name scripts to run just those (`./play_all.sh /tmp/plays play_shop play_river_town`). Quicker focused runs: `play_core`, `play_build`, `play_story`, `play_tutorial`, `play_dialogue`, `play_camera`, `play_overlays`, `play_interiors`, `play_shop`, `play_sleep`, and `play_cove` for Clockwork Cove.
- Character look-dev renders: `GODOT=... ./lookdev.sh out.png --view=lineup|close|faces`.
- Screenshots: `GODOT=... ./shot.sh out.png --pos=0,9,0 --cam=0.3,0.2,3.5 --time=19` (compatibility renderer; add `RENDERER=forward_plus` to see the game as it normally renders, with SSAO, glow and soft shadows).

### Data cheat sheet
- **Islands:** `islands.json` lists them; an island with a `layout_<id>.json` can be sailed to. A layout has `spawn` (new game), `arrive` (where the ferry lands), buildings, zones, nodes, features (a `boat`), nav graph, paths, `machines`, `props` and `decor`. Give its villagers `"island": "<id>"` in `npcs.json`; their requests belong to that island. The ground shape is a function in `scripts/systems/heightfield.gd`. Start on an island for screenshots with `--island=<id>`.
- **Rooms you can walk into:** give a building in `layout.json` an `interior` block: `shell` (`house` or `castle`), `items` (`[id, x, z, quarter-turns, colour?]`, build pieces or props: oven, barrel, crate, throne, banner, pillar), `route` (nav path from the door to where the owner works), `empty: true` for a room someone wants help with. Collision, the fading roof, the indoor camera and villager routes all follow from it.
- **Requests (`quests.json`):** objectives can have a `stage`; only the lowest unfinished stage is active. Kinds: `gather`, `event`, `build` (a live check), `room` (a checklist in a build zone), `pieces` (a count of pieces in a zone), `harmony`, `flag`, `pay` (hand coins or items to a villager), `talk` (`final` ones hand the request in; others are a step, with optional `lines`). `onDone` on an objective grants flags, items or blueprints when it completes.
- **Hours:** a request with `"hours": [from, to]` is only offered then (with `dialogue.later` as the "come back" line); an objective with `hours` only counts then. Windows can wrap past midnight (`[20, 4]`).
- **Benches:** a feature `{"kind": "bench", "x", "z", "r"}` in a layout is a bench you can sit or nap on.
- **Shops (`shops.json`):** per villager: `buys` (coins per item), `stock` (item bundles, blueprints or clothes for coins), `requires` for the shop or a line. Gift preferences are `likes` in `npcs.json`; treats carry a `treat` value in `resources.json`.
- **Build checks for requests:** a `build` objective's `check` can be `fed:<machine>` (water or power reaches a machine target), `path:<zone>` (a walkable path across a build zone, from its endpoint `a` to `b`: a bridge, a slipway), or `sealed:<zone>` (a wall across the zone keeps water from getting from `a` to `b`: give the zone a `seal` height, see `Validate.sealed`). A path can climb: an endpoint can say its height (`"y"`), so a climb inside a tower only counts at the top, and a step between cells may go up stairs.
- **Pieces that float:** `"placeOn": "water"` (the Pontoon) goes on open water only, with its deck just above the surface; planks rest on it.
- **What a node gives:** a `clay`, `flowers` or `fragment` node can say `"gives": {item: count}` (sand where others dig clay, mushrooms where others pick flowers), and a `fragment` can have a `name` (the lost thing it is). A `dig` spot (where the metal detector beeps) can say its own `gives` and `name` too, and any node can have its own prompt (`"label"`). The compass finds them. A node with `"once": true` is gone for good once taken, like a chest (a particular lost thing).
- **Villagers cross what you bridged:** a layout's `"crossings": [{a, b, zone}]` names two nav spots on either side of a build zone (on its endpoint `a` and `b` sides). Villagers walking between them follow the path the zone's last `path:<zone>` check found. Gate that nav edge on a flag (`[a, b, flag]`) set when the request is done.
- **A place that changes with the story:** a location script's `WORLD_FLAGS` lists the flags that reshape it, and its optional `adjust(layout, flags)` edits the layout for the ones set (moving a boat to its mooring, say). Its scenery reads `Data.world_flags`. When one of those flags changes, the world is built again where you stand once the conversation that set it ends. Loading a save at another point of the story rebuilds it too.
- **Fishing:** a layout's `"fish": [{id, name, weight, pull, item?, node?, flag?, hours?, caught?}]` replaces the shared catches there: `item` is what you get (default `fish`), `node`/`flag`/`hours` limit where and when it bites, `caught` is its toast; an empty `item` is one you put straight back. Each catch also sends the event `fish:<id>` for requests.
- **A request's weather:** `"onDone": {"weather": {"type": "rain", "hours": 6}}` brings that weather for a while (a storm for a finale).
- **A location's own meter:** `"meter"` in its map entry (`location.json`) replaces the approval rating while you're there: `name`, `icon`, `about`, `reward`, `display` (`from`, `per_point`, `format`, `to` where the reading stops) and `milestones` (`at`, `id`, `title`, `desc`, `items`, `blueprints`, `clothes`, `flags`). Its requests add points with `"meter": n` in their rewards, and a step can wait for it (`{"kind": "meter", "value": 250}`). See `LocationMeter`.
- **The bicycle:** unlocked in Boccapioppo, then ridden anywhere outdoors (`F` gets on and off, `H` rings the bell). Owning it and its upgrades are story flags, so any request or meter milestone can give them: `hasBike`, `bikeBell`, `bikeBasket`, `bikeLamp`, `bikeRack`, `bikePaint`. A place whose map entry says `"bikes": false` keeps you on foot. You get off by yourself to talk, build, gather or sleep, indoors and on stairs. A request can wait for the event `bike_ride` (25 m ridden in one go). See `Bicycle` and `BikeModel`.
- **Garden beds:** a layout's `"gardens": [{id, x, z, seed?, crop?, crop_name?, look?, need?}]` are its beds: the item planted (default `seeds`), what you pick (default 2 pumpkins and a seed), and how they look (`pumpkin`, `cabbage`, `leek`). Hearthglow keeps Gigia's four pumpkin beds.
- **Rooms upstairs:** a room on a raised floor (`"y"`) fades its roof only while you're on its storey, and a room can be tall (`"interior": {"height": 3.4}`) so you're still inside it up a climb. Build mode aims at raised floors and a site's `floorY`, and a site with `"interior": true` doesn't move you off it when you stop building. Furniture you place is used from its own storey.
- **Visitors:** a villager with `"visitor": true` (an inspector who comes for one request) doesn't need a request of their own; `"present": "<flag>"` keeps them away until then.
