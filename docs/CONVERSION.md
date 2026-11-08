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
     - the castle hall at dawn did not improve here: it stayed about 20% darker than before the conversion, because
       the old rim light lit shaded rooms. Step three fixed it with lamps in the hall.

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
   - **done:** the church, castle and workshop restyled with the kit, their shapes and gameplay unchanged:
     - the church has a gabled front with an arched stone portal and rose window, quoins, a sandstone footing and a
       coppi roof, and its brick tower has stone quoins, a stone belfry and a tiled spire that takes snow;
     - the workshop has a coppi roof that fades while you're inside, a stone door frame, kit windows with shutters,
       a footing and quoins;
     - the castle has tiled tower roofs that take snow, barred windows in the keep, a footing round the curtain wall,
       and two wall lamps in the hall with warm lights of their own, which bring the hall at dawn back to about its
       brightness before the conversion.

     Places without the kit keep the old buildings. Before and after: `docs/models/conversion_step3_c.jpg`.
4. **Characters.** Done:
   - **fabric per garment:** jeans and overalls are denim, shoes, boots and sandals leather, and tops, trousers and
     trainers stay knit (`Palette.denim`, `Palette.leather`);
   - **hair:** real specular, with the painted highlight band halved and the old rim fill removed, like every other
     material since step one (`Chibi.hair_code`);
   - **bodies of their own:** a villager's appearance can set a `body` (`height`, `width`, `belly`, kept within cute
     limits). The shape sits on a node of its own, so walking, sitting and every other pose are unchanged, and
     front details (an apron, a tie, buttons) move forward over a belly. Monteforchetta's cast and the Cove's have
     builds: a short, round Sindaco, a tall, lean electrician, a small computer whiz, a stocky baker and bus driver.
     The player keeps the standard body.

     Before and after: `docs/models/conversion_step4_6.jpg`.
5. **Other locations.** Boccapioppo, Toriano and Casalrana get the new materials through `Palette` automatically.
   Boccapioppo and Casalrana are now converted the way Monteforchetta was (08/11), and Toriano too, in a city's way
   (see "Toriano" below).
   - **Houses from the kit:** both places opt in with `"kit": true` in their `houseStyle`, and each house says
     `"kit": true` in the layout, whatever its kind. The location's own script still draws it, so a kit house keeps
     what the place adds on top:
     - Boccapioppo: its nine houses, Rina's bar (a shopfront with its sign and green awning, the payphone, the
       catfish photo), Primo's workshop (a one-storey shop with wheels hung either side), Ermes's oxblood house (pale
       quoins, the keeper's plaque), the station (pale quoins, its canopy, platform, clock and name boards) and the
       sawmill's office. Every one keeps the flood's tide line, now above the stone footing.
     - Casalrana: Paletta's cottage, the presbytery, the farm office and Cascina Grande, which has a long wooden
       gallery along its upper floor with a stair at its west end (`gallery`, `galleryStair`).
   - **Landmarks restyled with kit parts,** their shapes, rooms, doors and named parts unchanged:
     - Boccapioppo: the church (coppi roof, kit windows, an arched door, a rose window, stone copings, quoins and a
       footing; the bell tower with quoins, stone piers in the belfry and a tiled spire that takes snow), the arcade
       (coppi roof, kit windows with shutters on both floors, shop windows under the walk), the farm courtyard
       (coppi on all three wings, kit windows facing out, footings) and the pumping house (a footing, barred kit
       windows; its tin roof stays tin).
     - Casalrana: every building with a roof gets coppi laid tile by tile (the station, church, mill, machine shed,
       barn, cowshed and the farm workers' houses), and its windows, doors and chimneys come from the kit: shutters
       in faded green, open arched doorways into the rooms you walk into, a stone footing in place of the painted
       plinth. The bell tower's spire takes snow. The farm workers' houses stay shut up: every shutter closed, no
       light at night, a plain door for each family, and their gallery and stair rebuilt from kit parts.
     - Wood and tin stay as they were: Boccapioppo's houseboat, shack and dance hall, Casalrana's rice dryer.
   - **A denser core:** nine more kit houses in Boccapioppo (two attached pairs along the lanes under the levee and
     in the west of town, a pair and a single behind the north row of houses, and three on their own) and six in
     Casalrana (a row of three framing the crossroads lane, an attached pair facing the lane south of the square, a
     railway cottage by the crossing). They were placed with the same clearance check as Monteforchetta's: off
     lanes, villagers' routes, resource spots, building sites, features, trees and the square, on level ground.
     No gameplay data moved.
   - **Characters:** every villager in both places has a build of their own, from their description: in
     Boccapioppo a round old fisherman and his lanky nephew, a long-faced boatman, a wiry ex-racer, a stocky warden
     and sawmill owner, a short and steady postwoman; in Casalrana a round station master and priest, a big farm
     manager, a small 81-year-old nonna, a ten-year-old trainspotter and a tall railway inspector.
   - Before and after: `docs/models/conversion_step5_a.jpg` (Boccapioppo), `conversion_step5_b.jpg` (Casalrana) and
     `conversion_step5_c.jpg` (both casts).
   - **Toriano** (08/11) opts in with `"kit": true` in its `houseStyle`. A city block is not a village house, so it
     isn't assembled by `HouseKit`: Toriano's own kit (`scripts/locations/metropolis/kit.gd`) keeps each block's
     shape, cornice, hipped roof, balconies and awnings, and `metropolis/facades.gd` dresses it with the house kit's
     parts in place of the painted façade: plaster walls, a window per bay on every storey with shutters in the
     city's colours (open, ajar or shut), shop windows and doors on the ground floor with a granite base, and
     grilled windows under the flats at number 14. A bay whose outside is another building gets no window, so
     shared walls stay blank. Rooms you walk into (Franco's bar, the Works office, the lodge, the flats) keep their
     walls and doorways, with kit windows on the storeys above that fade while you're inside. Number 14's wings have
     3.2 m storeys (`"storey"` in the layout). The far backdrop ring and the landmarks (the Duomo, the Galleria's
     arcades, the Teatro, the castle, the station, the tram depot) keep their own styles. Every villager has a build
     of their own. Before and after: `docs/models/conversion_toriano.jpg`.
6. **Performance.** Done as far as it can be from here:
   - **a quality setting:** Settings has "Simpler graphics, for slower computers". It turns off screen-space
     reflections, contact shadows (SSAO) and multisample anti-aliasing, and gives the sun two shadow cascades out to
     45 m instead of four out to 70 m. It applies at once and is saved with the other settings.
   - **what a frame costs,** measured in a wide view of Monteforchetta (software Vulkan, 1280×720):

     | | Texture memory | Video memory | Draw calls | Triangles |
     | --- | --- | --- | --- | --- |
     | Before step three | 206 MB | 272 MB | 5,079 | 5.7 million |
     | Now, full graphics | 213 MB | 288 MB | 4,632 | 6.2 million |
     | Now, simpler graphics | 101 MB | 174 MB | 2,447 | 4.3 million |

     The kit houses added 7 MB of textures and about 10% more triangles, but fewer draw calls, because their parts
     are drawn as instances. Most of the triangles are the sun's shadow passes.
   - **the compatibility renderer:** every shader compiles, and the houses, church and piazza draw correctly. As
     before, that renderer is a little brighter and has no screen-space reflections.
   - **not measured: frame rate on real hardware.** Software rendering here runs at about one frame a second
     whatever the settings, so the numbers above are the guide until the game runs on a real card.

## Working alongside the graphics agent
The other agent works on light and colour, in `daylight.gd`, `terrain.gd`'s environment and `atmosphere.gd`. The
conversion works on materials and models. Both use `views.sh` and `measure_views.py` before and after, and record
what they change in `docs/GRAPHICS.md`, so neither undoes the other.
