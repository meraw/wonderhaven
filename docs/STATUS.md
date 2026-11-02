# Status

Working title: **Wonderhaven: The Lost Isles** — first chapter, Hearthglow Village (the vertical slice).

There are two versions with the same content:
- **Godot 4 (`godot/`)** — the version to play and develop from now on (the user's choice). See `godot/README.md`.
- **Web / Three.js (`index.html`, `src/`)** — the original prototype, kept as a reference. Content is exported from `src/data/` to `godot/data/`.

## What's in the slice (both versions unless noted)
- **World:** island terrain from one shared heightfield; village with castle, cottages, enterable workshop, bakery, caravan, dry fountain, river splitting off the orchard, spring and mill channel, quarry, harbor walled off by cliffs and a sealed gate; instanced trees, flowers, grass; day/night cycle with sunsets, lamps at night, sunny/cloudy/rain weather; ambient animals (butterflies, ducks, chickens) in Godot.
- **Character:** original chibi apprentice and seven villagers with expressive faces (blink, moods, talking), procedural walk/idle/actions; character creator and wardrobe with outfits that unlock in play.
- **Starforge build mode:** 47 pieces in four categories; zone grids; green/red ghost with plain-language reasons; snapping and half-grid; rotate, move, remove (refund), recolour; undo/redo; suggested quest blueprints; stacking, stairs, doors, wall-hung paintings, roofs on walls; bridges that really carry you (planks reach two tiles from a support); machines simulated (waterwheel/windmill → shafts/gears/levers → pump → pipes → fountain, spark lamps).
- **Villagers and story:** daily routines that react to your progress (they use the bridge you built), dialogue with live portraits and choices, friendship hearts and gifts, 12 quests (6 main: Starforge Tool, Orchard Bridge, Furnish the Workshop, Garden Fountain, Royal Decree, All Aboard!) with offers, tracking, turn-ins, rewards.
- **Gathering:** chop, mine and fish minigames; clay, flowers, acorns, apples; chests; treasure digging guided by the tool's hum; magic fragments; garden beds that grow over time; bakery squirrels.
- **Progression:** Kingdom Harmony with milestones (blueprints, bigger plot, harbor charter, sparkle trail, crown, every blueprint); journal, bag, progress screen, illustrated world map (other islands locked; the ferry sails to a "next chapter" preview), notice board.
- **Saves and settings:** three slots plus autosave on quests, building, resting and travel; volume, camera sensitivity, invert Y, weather toggle, key remapping; gamepad for movement, camera and menus.
- **Audio:** original procedural music (Hearthglow, night and build themes), synthesized sound effects, villager babble, ambience.

## How it was checked
- Godot: `godot/run_tests.sh` — 28 headless tests of the rules (walk physics, placement, span rule, machines, bridge path, quest flow, conversations, schedules, clock, minigames, gardening, save round-trip, data integrity), plus scripted playthroughs with real key and mouse events (`play_core`, `play_build`, `play_story`, `play_full`) rendered with software OpenGL and reviewed as screenshots.
- Web: `npm test` (45), `npm run build`; `npm run e2e` (last run passed checks 1–4 and 6, then its click-aiming failed at the bridge step).
- **Not checked:** how it feels on a real monitor at full frame rate, real gamepads, sound (the test machine has no audio device), Windows/macOS. Please report anything that looks or feels off.

## Not done yet
- Remapping gamepad buttons (keys can be remapped). Gamepad build controls exist but were not tested on a real controller.
- The other four islands (Clockwork Cove, Blooming Wilds, Starlight Shores, Moonveil Hollow), Acts 2–3, the central landmark, programmable mechanisms and the elevator puzzle, postgame quests.
