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
  See `metropolis/` for a city that uses them.
- `location.json`: its entry on the travel map (`name`, `desc`, `x`, `y`, `r`, `color`, `reveal`) and its `look`.
- `npcs.json`, `quests.json`, `shops.json`, `resources.json`: the same shapes as the shared files in `..`, holding
  only this location's entries. Prefix every id with the location id.

Code for the location goes in `godot/scripts/locations/<id>.gd`.
