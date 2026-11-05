# Location packs

Each folder here is one location of the game, kept apart so several people can build locations at the same time.
See `docs/WORLD.md` for the rules and the file shapes. A pack is picked up when its folder has a `layout.json`.

- `layout.json` (required): the same shape as `../layout_clockwork.json`. Optional extras for places that aren't
  villages:
  - `size`: the ground's width in metres (default 124).
  - `ground`: paving painted over the grass, in order, from `scripts/systems/ground.gd`.
  - `decor.area`: `[x0, z0, x1, z1]`, the box where random greenery grows, with counts for `trees`, `bushes`,
    `flowers` and `grass`.
  - `h` on a building: its height, for the camera.
  - `depart_label` on the departure point: how you leave, for example "Take the train".
  - `floors`: raised floors you walk and build on (balconies, roof terraces, stairs, bridge decks; see
    `WorldStatics.floors`), `roof_walk` on a building for a walkable roof, `y` on a building that stands on one,
    `floorY` on a build site up there, `solid: false` for scenery-only buildings.
  - features of kind `stop` with a `line`: ride between stops (`Travel.stops_on`). Riding to a stop raises the
    request event `ride:<stop id>`.
  - `y` on a feature that stands on a raised floor; `flag` on a wardrobe that's yours only once it's set.
  - `catches`: what fishing gives here, in place of fish (`{id, name, weight, pull, item}`; see `Minigames.FISH`).
  - `lost`: what the lost things turn out to be here.
  - on a gathering node: `label` (what the prompt says), `hours: [from, to]` (only out then), `loot` (a bin's or a
    dig spot's finds), `lines` (a bin's), `text` (a dig spot's), and `item` and `name` (a "lost thing" that is
    something else, a page of a score, say).
  - zone `endpoints` may lie just outside the build site, and `b` can need you to stand at least `minY` high; a
    request checks the path with the build check `path:<zone>`.
  See `metropolis/` for a city that uses them.
- `location.json`: its entry on the travel map (`name`, `desc`, `x`, `y`, `r`, `color`, `reveal`) and its `look`. The
  place stays off the map until its `reveal` flag is set (`Travel.on_map`). An optional `meter` gives the place its
  own progress meter in place of the approval rating (`Meter`): requests there add their `harmony` reward to it.
- `npcs.json`, `quests.json`, `shops.json`, `resources.json`: the same shapes as the shared files in `..`, holding
  only this location's entries. Prefix every id with the location id.

Code for the location goes in `godot/scripts/locations/<id>.gd`.
