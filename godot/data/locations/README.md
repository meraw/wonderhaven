# Location packs

Each folder here is one location of the game, kept apart so several people can build locations at the same time.
See `docs/WORLD.md` for the rules and the file shapes. A pack is picked up when its folder has a `layout.json`.

- `layout.json` (required): the same shape as `../layout_clockwork.json`.
- `location.json`: its entry on the travel map (`name`, `desc`, `x`, `y`, `r`, `color`, `reveal`) and its `look`.
- `npcs.json`, `quests.json`, `shops.json`, `resources.json`: the same shapes as the shared files in `..`, holding
  only this location's entries. Prefix every id with the location id.

Code for the location goes in `godot/scripts/locations/<id>.gd`.
