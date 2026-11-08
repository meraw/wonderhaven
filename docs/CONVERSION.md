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
2. **Ground and wet.** Done in the second step (`docs/GRAPHICS.md`, "Ground and wet").
   - The terrain gets real specular but keeps its wrapped light, and dry grass has no specular, so meadows look as
     before.
   - The squares are laid with the generated flagstones (relief and roughness), tinted with the layout's cobble
     colours. The texture is calmed first (`tools/textures/game_paving.py`), and the castle hall's floor uses it too.
     This reaches every place with a square: Monteforchetta, Boccapioppo, Casalrana and the Cove.
   - Wet paving and paths turn glossy; puddles are mirrors, stronger than real water because the camera looks down
     from high up; raindrop rings stay. Toriano's asphalt and setts, and every place's paved streets, get the same.
   - Screen-space reflections in Forward+. In the compatibility renderer every shader compiles, but the puddles are
     faint (no screen-space reflections, only a dim sky), and the morning piazza comes out 3% brighter than after
     step one.
   - A little ambient fill stays at night.
   - Dirt paths keep their painted look: a generated cobble texture for them is still to do.
   - **What it showed, measured against the fixed views** (step one's renders as the baseline):
     - dry daytime views moved by 2% or less;
     - rain gained contrast and its puddles now mirror the sky and the village;
     - night is 8% brighter than in step one (8% darker than before the conversion);
     - the castle hall at dawn did not improve. It stays about 20% darker than before the conversion: the old rim
       light lit shaded rooms, and the rebuilt hall in step three should bring its own light (windows, lamps).

     Before-and-after images: `docs/models/conversion_step2_a.jpg` and `conversion_step2_b.jpg`.
3. **Buildings and the village:**
   - **done:** Monteforchetta's houses and shops are assembled from a Blender kit of parts, from layout data
     (`docs/MODELS.md`, "The house kit"). Collision stays the footprint, upper floors and roofs fade while you're
     inside, windows light at night, and the coppi take snow. Before and after: `docs/models/conversion_step3_a.jpg`;
   - **done:** Monteforchetta's core made denser and varied: ten more kit houses, of two and three storeys in different
     colours, some attached in rows, as decided in the look tests:
     - two frame the piazza's north side, either side of the lane to the bridge;
     - one stands between the piazza and the newsstand, one beside the church;
     - a terrace of four lines the south lane toward the belvedere;
     - two stand at the village gate, where the bus stops.

     They were placed clear of every lane, villagers' route, resource spot, building site, bench, sign and hangout,
     with no change to gameplay data. Before and after: `docs/models/conversion_step3_b.jpg`;
   - the code-built church, castle and workshop restyled.
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
