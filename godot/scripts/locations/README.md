# Location scripts

`<id>.gd` belongs to the location pack in `godot/data/locations/<id>/`. Every function is optional and static:

- `height(x, z) -> float`: the ground shape (water below `Heightfield.WALKABLE_MIN`).
- `is_stream_cell(i, k) -> bool`: build-grid cells with flowing water, for waterwheels.
- `building(b: Dictionary) -> Node3D`: a model for one of the layout's buildings, or `null` to use the shared ones.
- `dress(village: Village) -> void`: extra scenery, added after everything else is built.

Put helpers for a big location in `godot/scripts/locations/<id>/`. See `docs/WORLD.md`.
