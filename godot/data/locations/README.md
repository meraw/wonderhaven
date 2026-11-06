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
  - `fish`: what bites here, in place of the shared fish (`Minigames.catch_table`; `caught` is what the toast says).
  - `lost`: what the lost things turn out to be here.
  - on a gathering node: `gives` (`WorldActions.gives`: what it gives, for bins and dig spots too), `name` (a
    particular lost thing, or a page of a score), `label` (what the prompt says), `hours: [from, to]` (only out
    then), `lines` (a bin's) and `text` (a dig spot's).
  - zone `endpoints` may lie just outside the build site (`Validate.path_across`), and an endpoint can say how high
    it is (`y`: up on a roof terrace); a request checks the path with the build check `path:<zone>`.
  See `metropolis/` for a city that uses them.
- `location.json`: its entry on the travel map (`name`, `desc`, `x`, `y`, `r`, `color`, `reveal`) and its `look`. The
  place stays off the map until its `reveal` flag is set (`Travel.on_map`). An optional `meter` gives the place its
  own progress meter in place of the approval rating (`LocationMeter`): requests there add their `meter` reward to
  it, a milestone can wait for a request (`requires`), and build sites there grow with it.
- `npcs.json`, `quests.json`, `shops.json`, `resources.json`: the same shapes as the shared files in `..`, holding
  only this location's entries. Prefix every id with the location id.

Code for the location goes in `godot/scripts/locations/<id>.gd`.
