# Status

Working title: **Wonderhaven: The Lost Isles**. First pass: the Hearthglow Village vertical slice.

## Phase 1 — Core (done)
- Island terrain from a shared heightfield: village core, river with steep banks, spring and mill channel, castle mound, southern harbor cove walled by cliffs and a sealed gate.
- Village: workshop (hollow, enterable), bakery, cottages, caravan, castle, fountain (dry), harbor stall, broken bridge posts, lamps, fences, instanced trees/bushes/flowers/grass, sandy paths, painted plaza.
- Chibi player with canvas face (blinking, expressions), procedural walk/idle and action animations.
- Camera-relative WASD movement, running, hopping, step-up, wall sliding, water blocking. Orbit camera: drag, Q/Z, wheel zoom, gamepad sticks.
- Interaction: nearest target in front glows, with an "E" prompt (signs so far).
- Tests: walk physics, terrain/zone geometry, bindings. Verified in headless Chromium: movement, camera drag, zoom.

## Phase 2 — Magical construction (done)
- 47 buildable pieces in four categories (structure, furniture, outdoor, mechanisms), each with its own low-poly model, cost and rules (`src/data/pieces.js`).
- Build mode (B): camera eases to a construction view, glowing zone grids (locked zones shown greyed), category catalog with locked/unlocked and costs, transparent green/red preview with a plain-language reason, purple suggested blueprint for quest zones.
- Grid snapping with optional half-grid (G), rotation (R), stacking onto walkable tops, wall-hung paintings, roofs on walls, stairs that you can climb, doors you can open.
- Select a placed piece to move (M), rotate, remove (Delete, full refund) or recolour (T / swatches). Undo/redo (Ctrl+Z / Ctrl+Y) for place, remove, move, recolour.
- Bridge physics: planks reach two tiles out over water from a bank, a post or an old piling. Placed pieces become real walk surfaces and colliders.
- Machines: waterwheels in flowing water and windmills make power; shafts, gear boxes and switched-on levers carry it; powered pumps beside water push it through pipes to fountains; spark lamps light when powered. Simulated in `src/systems/mechanics.js`, animated in the world.
- Tests: placement, rotation, stacking, zone and overlap warnings, span rule, removal safety, doors, stairs, the full fountain mechanism (and how it fails), lever switching, bridge path validation and walking across, dock. Verified in headless Chromium: build mode opens, catalog clicks, mouse placement of a bridge, invalid-placement reason, walking across the built bridge with W.

## Still to do in this pass
Phases 3–5 of the plan: resources and minigames, NPCs/dialogue/quests/Harmony, the four starter quests, customisation, audio, day/night, saves.

## Later
Clockwork Cove, Blooming Wilds, Starlight Shores, Moonveil Hollow; Acts 2–3; postgame.
