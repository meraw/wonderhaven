# Location scripts

`<id>.gd` belongs to the location pack in `godot/data/locations/<id>/`. Every function is optional and static:

- `height(x, z) -> float`: the ground shape (water below `Heightfield.WALKABLE_MIN`).
- `is_stream_cell(i, k) -> bool`: build-grid cells with flowing water, for waterwheels.
- `paint(x, z) -> Color`: the ground's colour (stubble, mud, winter grass) instead of meadow green; its alpha is how
  much meadow grows there (clover and flowers in the terrain, grass tufts, flowers, bushes and trees). Paving laid out
  as shapes belongs in the layout's `ground` list instead.
- `building(b: Dictionary) -> Node3D`: a model for one of the layout's buildings, or `null` to use the shared ones.
- `dress(village: Village) -> void`: extra scenery, added after everything else is built.
- `const WORLD_FLAGS := [...]`: story flags that reshape the place. When one changes, the world is built again where
  you stand (after the conversation that set it). `building()` and `dress()` can read `Data.world_flags`, the ones
  that are set.
- `adjust(layout: Dictionary, flags: Dictionary) -> void`: edits the freshly read layout for those flags (a boat moved
  to its mooring, a new floor, a nav spot). It's called whenever the world is built.

Put helpers for a big location in `godot/scripts/locations/<id>/`. See `docs/WORLD.md`.
