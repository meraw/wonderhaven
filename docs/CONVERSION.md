# Converting the game to the chosen look

The look was chosen after the look tests in `docs/MODELS.md`:
- cute proportions with materials as real as possible;
- textures mixed per material;
- outlines kept;
- attached but varied houses;
- eyes at 1.45×.

This is the plan for bringing it into the game itself, written from a fresh look at the graphics on 07/11. Before
it, the other agent had landed ACES tonemapping (white point 4), a sun nearly three times the ambient, a layout's
own cobble colours, and `views.sh` with `measure_views.py` for before-and-after views (`docs/GRAPHICS.md`).

## What draws what
- **`Palette`** (`scripts/world/palette.gd`) makes the materials for nearly everything built in code:
  - 421 plain-colour materials (`P.mat`);
  - 150 wood, 84 stone, 30 plaster, 25 fabric and 4 smooth;
  - 39 one-off materials (`P.unique_mat`).

  Changing it changes buildings, props, furniture, build pieces, animals and the chibis' clothes everywhere, in
  every location.
- **Custom shaders:**
  - `terrain.gd`: the ground (grass, paths, cobbles, wet ground and puddles), water, sky, the far hills and the
    valley fog;
  - `props.gd`: the coppi roofs;
  - `foliage.gd`: plants;
  - `chibi.gd`: hair;
  - `face_shader.gd`: faces;
  - `outline.gd`: the ink lines;
  - `atmosphere.gd`: the screen pass;
  - Toriano's facade kit, Boccapioppo's mist, Casalrana's textures.
- **The environment:**
  - `TerrainBuilder.build_environment`: tonemapping, SSAO, glow;
  - `Atmosphere`: grade, fog and ambient light, every frame.
- **A few location scripts** make their own `StandardMaterial3D`s. These are already physically based by Godot's
  defaults.

## Phases
1. **Materials.** Done in this first step.
   - `Palette` makes physically based materials: Burley diffuse, real specular, roughness.
   - The chosen texture mix is now game textures (`assets/textures/materials/`, VRAM-compressed, with mipmaps):
     - plaster: generated;
     - stone and wood: photo-scanned;
     - fabric: generated knit.

     Plain colours keep their faint mottle.
   - The roof and Toriano facade shaders switch to real specular. The terrain keeps its wrapped light until step two
     (`docs/GRAPHICS.md`).
   - Foliage, water, the far hills, hair and faces keep their own shading, so plants stay stylised.
   - Outlines stay on.
   - `--look=painted` brings back the old materials, for comparisons.
   - **What it took, measured against the ten fixed views** (`views.sh`, `measure_views.py`):
     - the generated plaster's colour variation cut to a third, and its relief halved, because on the game's small,
       pale houses it read as dirt;
     - specular 0.25 on rough surfaces;
     - a stronger, warmer ambient light, to replace the fill the old rim light gave (`docs/GRAPHICS.md`).

     Result: contrast up in every view, colour about where it was, and the castle hall at dawn 11% darker than
     before. Before-and-after images: `docs/models/conversion_step1_a.jpg` and `conversion_step1_b.jpg`.
2. **Ground and wet:**
   - the terrain's cobbles and paths use the generated flagstones and cobbles (relief and roughness) instead of
     painted ones;
   - wet ground gets glossy, with puddles;
   - screen-space reflections in Forward+;
   - check the compatibility renderer.
3. **Buildings and the village:**
   - a building's `"model"` in the layout loads a Blender house in the real village. Collision stays the layout
     footprint; the roof must fade, windows light at night, roofs take snow (`docs/MODELS.md`);
   - Monteforchetta relaid as a dense, varied core;
   - the code-built church, castle and shops replaced or restyled.
4. **Characters:**
   - fabric chosen per garment (knit, denim, leather) instead of knit for everything;
   - hair material;
   - villagers with bodies of their own (silhouettes).
5. **Other locations.** Boccapioppo, Toriano and Casalrana get the new materials through `Palette` automatically.
   Their own buildings and shaders are their owners' to convert, the same way.
6. **Performance:**
   - frame rate on real hardware (only measurable on the user's machines);
   - texture memory;
   - a quality setting for slower machines (possibly the painted look);
   - the compatibility renderer.

## Working alongside the graphics agent
The other agent works on light and colour, in `daylight.gd`, `terrain.gd`'s environment and `atmosphere.gd`. The
conversion works on materials and models. Both use `views.sh` and `measure_views.py` before and after, and record
what they change in `docs/GRAPHICS.md`, so neither undoes the other.
