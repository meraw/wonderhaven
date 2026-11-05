# Location scripts

`<id>.gd` belongs to the location pack in `godot/data/locations/<id>/`. Every function is optional and static:

- `height(x, z) -> float`: the ground shape (water below `Heightfield.WALKABLE_MIN`).
- `is_stream_cell(i, k) -> bool`: build-grid cells with flowing water, for waterwheels.
- `paint(x, z) -> Color`: the ground's colour (stubble, mud, winter grass) instead of meadow green; its alpha is how
  much meadow grows there (clover and flowers in the terrain, grass tufts, flowers, bushes and trees). Paving laid out
  as shapes belongs in the layout's `ground` list instead.
- `building(b: Dictionary) -> Node3D`: a model for one of the layout's buildings, or `null` to use the shared ones.
- `node(n: Dictionary) -> Node3D`: a model for one of the layout's gathering spots (`nodes`), or `null` to use the
  shared one. The shared code positions it and animates its usual parts: a bin's `lid` child, a tree's stump.
- `dress(village: Village) -> void`: extra scenery, added after everything else is built.

Put helpers for a big location in `godot/scripts/locations/<id>/`. See `docs/WORLD.md`.
