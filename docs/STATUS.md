# Status

Working title: **Wonderhaven: The Lost Isles** — first chapter, Hearthglow Village (the vertical slice).

- **Godot 4 (`godot/`)** is the game. See `godot/README.md`. Its content (`godot/data/*.json`) is edited directly.
- **Web / Three.js (`index.html`, `src/`)** is the original prototype, **frozen**: kept as it was, no longer updated. Everything added since the Godot port (interiors, shops, staged requests, the guided day, the look) exists only in Godot.

The story and characters are placeholders the user plans to rework; the focus is on mechanics that carry over to new islands.

## What's in the slice (Godot)
- **World:** island terrain from one shared heightfield; village with castle, cottages, workshop, bakery, caravan, dry fountain, river splitting off the orchard, spring and mill channel, quarry, harbor walled off by cliffs and a sealed gate; instanced trees, flowers, grass; ambient animals.
- **Time and weather:** the day is split into dawn, morning, afternoon, evening and night, each with its own music and a sky that changes gradually; sunny, cloudy and rainy spells.
- **Rooms you can walk into:** every house and shop and the castle: the bakery (Mabel bakes behind her counter), Fern's and Odessa's cottages, the Lantern Inn (your bed and wardrobe are inside), the Captain's hut and the castle's throne room. The Old Gatehouse is empty (someone could want help furnishing it) and Bram's workshop is his request. Inside, the roof fades and the camera looks down over the walls; villagers walk in to work and sleep. Rooms, furniture and routes are data (`interior` blocks in `layout.json`).
- **Character:** original chibi apprentice and seven villagers with expressive faces (blink, moods, talking), procedural walk/idle/actions; character creator with five distinct dot-eye styles and mouths, wardrobe with outfits that unlock in play.
- **Story start:** an arrival card sets the scene (a traveller answering Odessa's "Builder wanted" notice, staying at the Lantern Inn). King Percival rules from the castle.
- **Guided first day:** a skippable walkthrough from Odessa, one step at a time (walk, look, talk, chop, bag, fragment, return, journal, meet Fern, gather for the bridge, build it, add railings). HUD parts appear as they're introduced; one-time tip cards explain talking, chopping, mining, fishing, building, Harmony, the journal and the map (`godot/data/tutorial.json`).
- **Requests that take a while:** requests come in steps (stages): gather materials first, then build, then finishing touches; the tracker and journal show "Step 2 of 3" and only the current step. Step types: gather, events, live build checks, room checklists, piece counts in a zone, paying a villager, talking to someone mid-request. Examples: the bridge (10 wood and 8 Spark, build it, 4 railings), Bram's workshop (wood, metal and a crystal, hear his plan, then two seats, two lamps, two shelves, a workbench and a splash of colour), your own home (pay King Percival 100 coins for the deed, build a house, make it cosy), the fountain and the dock (materials first). 13 requests, 7 of them main story.
- **Coins, shops and gifts:** coins come from requests, chests, digging and selling. Bram, Fern, Tilly, Mabel and the Captain run shops (choose "🛍" in conversation): sell them what they want, buy materials, blueprints and Mabel's treats (`godot/data/shops.json`). Give any villager one gift a day; things they love and treats raise friendship more, and friendship unlocks their own gifts.
- **Following the story:** the next main-story request is always shown, so side requests never hide it; the compass points at the next step (the nearest place to gather an item, or the person to talk to or pay).
- **Starforge build mode:** 47 pieces in four categories; zone grids; green/red ghost with plain-language reasons; snapping and half-grid; rotate, move, remove (refund), recolour; undo/redo; stacking, stairs, doors, paintings, roofs on walls; bridges that really carry you; machines simulated (waterwheel/windmill → shafts/gears/levers → pump → pipes → fountain, spark lamps). The checklist on the right shows the request's current step. When you leave build mode standing on the site (or stuck in what you built), you step off to the nearest free spot outside it.
- **Unstuck:** Menu → 🆘 I'm stuck takes you back to the inn door.
- **Gathering:** chop, mine and fish minigames; clay, flowers, acorns, apples; chests; treasure digging; magic fragments; garden beds that grow over time; bakery squirrels.
- **Progression:** Kingdom Harmony with milestones; journal, bag, progress screen, world map (other islands locked; the ferry sails to a "next chapter" preview), notice board.
- **Saves and settings:** three slots plus autosave; volume, camera sensitivity, invert Y, weather and outline toggles, fullscreen, key remapping; gamepad for movement, camera and menus.
- **Look and sound:** ink outlines, surface textures, rounded fonts, soft lighting with SSAO and glow (Forward+), original procedural music and sound effects.

## How it was checked
- `godot/run_tests.sh`: 66 headless tests of the rules (walk physics, placement, span rule, machines, bridge path, staged quest flow, paying and talk steps, shops and gifts, conversations, schedules, clock, minigames, gardening, save round-trip, tutorial, data integrity, camera collision and the indoor camera, interiors).
- Scripted playthroughs with real key and mouse events, reviewed as screenshots: `play_core`, `play_build`, `play_story`, `play_dialogue`, `play_tutorial`, `play_camera`, `play_overlays`, `play_interiors` (walks into every room; Mabel at work; talking indoors), `play_shop` (buy, sell, give a gift), and the full playthrough in two parts (`play_full`, `play_full2`). See the latest PR description for which passed.
- Web (frozen): `npm test`, `npm run build`.
- **Not checked:** how it feels on a real monitor at full frame rate, real gamepads, sound (the test machine has no audio device), Windows/macOS, and how long the requests take a real player. Please report anything that looks or feels off.

## Not done yet
- Furnishing the Old Gatehouse as a request; more shop stock and clothes to buy.
- Remapping gamepad buttons (keys can be remapped). Gamepad build controls exist but were not tested on a real controller.
- The other four islands (Clockwork Cove, Blooming Wilds, Starlight Shores, Moonveil Hollow), Acts 2–3, the central landmark, programmable mechanisms and the elevator puzzle, postgame quests.
