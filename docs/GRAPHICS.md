# Graphics notes

How the Godot version gets its look, the general principles behind it, and what to try next. Everything here works from
shared shaders and the clock, not from any one island's layout, so a new island gets the same treatment for free.

## Principles

These hold for any cozy, stylised 3D game with a painted look, not only this one.

1. **One world, shared values.** Wind, sun direction and colour, weather and sky colours are shader globals
   (`[shader_globals]` in `project.godot`), set once a frame by `scripts/world/atmosphere.gd`. Every shader reads the
   same values, so grass waves, water ripples, drifting clouds and their shadows all move the same way, and rain darkens
   the ground, the plants and the puddles at once. Per-object random motion reads as noise; shared motion reads as air.
2. **In a soft painted style, detail lives in colour, not relief.** Normal maps were tried on plaster, wood and stone
   and removed: wrapped diffuse lighting flattens small bumps, and the rim light turns bumpy normals into a general
   brightening. Painted detail does the job: brush-like hatching, colour drifts, scattered clover and flowers,
   highlight dabs on leaf clusters.
3. **Details fade before they shimmer.** Shaders measure metres per pixel (`fwidth`) and fade fine detail with distance.
   Scattered details use a sine-free hash, because the common `fract(sin(...))` hash lines dots up in rows.
4. **Painted lighting follows the real sun.** Pebbles and cobblestones get a lit edge toward the sun and a shaded or
   shadowed edge away from it, using the actual sun direction, so they turn with the time of day. Small objects should
   be paler than the ground they sit on; darker spots with a lit edge read as holes.
5. **Light has colour on every side.** A warm key light, a cool sky ambient, and a weak green-warm bounce from the
   ground that lights eaves, canopy undersides and chins. Each is subtle; together they give form.
6. **Let light pass through thin things.** Leaves and grass transmit light (backlight) and their edges glow when you
   look toward a low sun. This is most of what makes golden hour feel golden.
7. **Weather changes materials, not just particles.** Rain darkens grass, sand, dirt and stone, fills puddles that
   mirror the sky (more at a low angle), and drops rings on puddles and water.
8. **Water is depth, sky and sparkle.** Tint by depth, mirror the sky by Fresnel (distant water reflects, near water
   shows its bed), add sun or moon glitter on ripple crests, and caustics on shallow beds. Build ripple normals from
   smooth (quintic) noise with rotated octaves, or the noise grid shows.
9. **Tonemap before you grade, and give the sun room.** With a linear tonemapper anything brighter than white clips
   flat, so the sun has to stay weak and the picture goes flat: lit and shaded sides barely differ. A filmic curve
   rolls highlights off instead, so the sun can be two to three times the ambient fill and shapes read. Pick the curve
   by eye on lamps, lit windows and golden hour: those are what a curve drains first.
10. **Grade gently.** A colour grade sets the mood of each hour (rosy dawn, neutral noon, warm dusk, blue night), but
   strong highlight tints dull saturated greens and kill the warmth of lamp light. Keep highlights close to white and
   tint mostly the shadows.
11. **Use distance for mood.** Haze (fog) and a slight blur on the far distance make an island read like a miniature
    diorama and keep attention near the player.
12. **Ambient life carries the atmosphere.** Dust motes in sunshine, fireflies on dry nights, leaves falling from the
    nearest real tree and drifting downwind: small, cheap, tied to the hour and the weather.
13. **Check your own work in pictures and motion.** Render the same views at the same hours before and after a change,
    compare them side by side, measure average brightness so a grade doesn't drift, and record a short clip, because
    wind, glitter and particles only show in motion. `godot/views.sh` renders ten fixed views and
    `godot/measure_views.py` puts their brightness, contrast, clipping and saturation side by side.

## What the game does now

| Effect | Where | Renderer |
| --- | --- | --- |
| Shared wind, sun, weather and sky values | `atmosphere.gd`, `project.godot` | all |
| Gusts that roll across plants downwind; leaf flutter; painted leaf clusters; light through leaves; warm grass tips; glowing edges toward a low sun | `foliage.gd` (plant shader), `props.gd` (single trees) | all |
| Ground: brush-like hatching, warm and cool colour drifts, earthier slopes, drier high ground, clover and tiny flowers | `terrain.gd` (terrain shader) | all |
| Pebbles and cobblestones lit from the sun's side | terrain shader | all |
| Wet ground, puddles that mirror the sky, raindrop rings | terrain shader | all |
| Caustics on shallow river and pond beds | terrain shader | all |
| Water: Fresnel sky reflection, sun and moon glitter, smooth ripples, rain rings | `terrain.gd` (water shader) | all |
| Sky clouds drift downwind | `terrain.gd` (sky shader) | all |
| Ground bounce light | `atmosphere.gd` | all |
| ACES tonemapping (white point 4, exposure 0.92; 0.78 in the compatibility renderer), a sun nearly three times the ambient by day, a brighter moon and ambient at night | `terrain.gd` (`build_environment`), `daylight.gd` (`KEYS`) | all |
| Watercolour-and-pencil icons for the resources, the HUD, the menus and the weather, as a colour font the UI fonts try before the one-colour icon fonts (`tools/icons/`) | `ui_theme.gd` (`drawn_icon_font`), `assets/fonts/WonderhavenIcons.ttf` | all |
| Build pieces shown as small renders of their own models (ink outline, game lighting) on the build bar and panels | `tests/render_piece_icons.gd`, `assets/icons/pieces/`, `build_mode.gd` (`piece_icon`) | all |
| A layout's own cobblestones (`cobbleColors`: Monteforchetta's warm grey local stone instead of pale granite) | `terrain.gd` (terrain shader `cobble_a`, `cobble_b`) | all |
| Colour grade that follows the hour and weather | `atmosphere.gd` (environment colour correction) | all |
| Cloud shadows matching the sky's clouds, soft vignette | `atmosphere.gd` (screen pass) | Forward+ |
| Slight blur on the far distance | `atmosphere.gd` (camera attributes) | Forward+ |
| Dust motes, fireflies, falling leaves | `atmosphere.gd` (GPU particles) | all |
| Valley fog: a sheet of mist below a hilltop, thick at dawn and gone by late morning, thinning along a ragged edge where the ground comes up through it | `terrain.gd` (valley fog shader), `atmosphere.gd` (amount by the hour) | all; soft edges against the far hills need Forward+ |
| Far hills: vertex-coloured fields, woods and autumn vineyards, with rows striped along the contours that fade out before they could shimmer; hilltop villages; the Alps | `terrain.gd` (backdrop, hills shader) | all |
| Curved terracotta roof tiles (coppi): ribs of rounded caps and hollow pans, with the light tilted across each channel | `props.gd` (roof shader, `style`) | all |

The atmosphere module only reads the clock, the weather and the player's position. It does not touch rules, saves or
layouts, and the game loads it the same way as the animals module.

## Physically based materials (conversion, step one)
`Palette` makes physically based materials since the conversion to the chosen look (`docs/CONVERSION.md`). Three
things carried over from the painted look had to be handled:
- **The old rim light was a hidden fill.** Godot narrows the rim by roughness, and at roughness 1 (every painted
  material) it doesn't narrow at all. So the painted look added a quarter of the sun's light, warm, to every surface,
  whichever way it faced. Shaded sides and interiors stayed warm and bright because of it, and the day's sun and
  ambient balance (above) was tuned with it in place. Without it, a facade facing away from the sun lost half its
  brightness and went grey, and the castle hall at dawn a third.
- **Ambient light stands in for it.** By day, with realistic materials, the ambient is 1.35 times stronger and 30%
  of the way to the sun's colour, so the fill is warm as before. Both fade out at night, when the moon gave little
  rim light (`Palette.ambient_gain`, `Palette.ambient_color`, applied in `game.gd`). `--look=painted` keeps the old
  ambient.
- **Godot's wrapped light halves the sun at roughness 1.** Its Lambert wrap gives a face turned straight to the sun
  only half the light, and gives the other half to the faces turned away. So realistic diffuse doubles the sun on
  sunlit faces, which matters most on the ground. The terrain keeps its wrapped light until step two of the
  conversion gives it textures and wet ground (`docs/CONVERSION.md`). The roof and Toriano facade shaders, which had
  no rim fill, are 10% darker with realistic materials (`Palette.REAL_SHADER_ALBEDO`).
- **Rough surfaces reflect less.** At the default specular, rough plaster, stone and fabric reflected the bluish sky
  and greyed warm colours (12 to 15% less saturation). They use 0.25; smooth ones 0.5.

## Ground and wet (conversion, step two)
The terrain shader has a realistic variant too (`TerrainBuilder.terrain_code`, a `REAL` switch in the shader;
`--look=painted` keeps the old ground).
- **Grass keeps its soft wrapped light** and, dry, no specular at all, so it looks as it did. Only the light's model
  changed (`specular_schlick_ggx`): wet grass gets a faint sheen.
- **Flagstones in the squares.** The generated flagstones from the look tests replace the painted cobbles, tinted with
  the layout's `cobbleColors`, with their relief and roughness. The texture is calmed first
  (`tools/textures/game_paving.py`): at full contrast the grout went black and the stones patchy on the pale squares.
  The castle hall's floor uses the same stones (`Palette.paving`). The kerb ring stays painted.
- **Wet ground is glossy.** Paving and paths drop to roughness 0.25 in the rain (dirt paths less), with stronger
  specular, and get darker than before (45% instead of 30%), because a smoother surface takes more of the wrapped sun.
- **Puddles are mirrors, more than real water would be.** From the game's raised camera, real water reflects about a
  tenth of the sky, and puddles disappeared. They are treated as 80% metallic with a mid-grey tint: dark underneath,
  bright with the sky and the village above. Raindrop rings are drawn on top. A little of the old painted sky tint
  stays (15%); in the compatibility renderer, which has no screen-space reflections, puddles are faint.
- **The generated flagstones have a few curved double edges**, from tiling 4D noise into a square texture. They read
  as cracks, and the lab floor had them too; a periodic 2D cell pattern in `tools/blender/make_textures.py` would
  remove them.
- **Screen-space reflections** (Forward+ only) put what stands nearby into the puddles (the noticeboard's post in the
  rain view); off screen, puddles fall back to the sky. Their cost on a real graphics card is not measured yet.
- **A little ambient fill stays at night** (1.15 instead of 1.0): night had come out 15% darker in step one.
- **The castle hall at dawn** stayed about 20% darker than before the conversion, and cooler, until step three.
  The dawn ambient was already at full strength: the loss was the old rim light's warm fill, which reached shaded
  surfaces too, and a room in full shadow at dawn has nothing else. A raised ambient would have washed out every
  daytime shadow. Step three gives the hall two wall lamps with warm lights of their own (no shadows, 4.6 m reach):
  at dawn the hall is now about as bright as before the conversion, and warm again.

## Tried and dropped
- **Normal maps from the detail textures** (plaster, wood, stone, fabric). Invisible at gentle strengths, and at
  visible strengths the rim light made surfaces lighter and flatter. Fabric relief also broke on character meshes that
  have vertices without a usable normal.
- **A strong colour grade.** The first version tinted highlights warm and lifted shadows by up to 8%: sunsets turned
  olive and night lamps lost their warmth. The current grade stays within a few percent of neutral.
- **AgX tonemapping** (Godot 4.4). It ended clipping, but drained colour from everything bright: lit windows and the
  church's rose window went cream or peach, lamps nearly white, golden hour neutral. Deeper amber lamp colours mixed
  with tinted glass into peach; weaker lamps went pale. ACES kept the warmth.
- **Filmic tonemapping.** Washed out at the same exposure.
- **More contrast in the environment adjustment** (1.06 to 1.1). It pivots at mid-grey, so dark scenes got darker:
  night 22% and golden hour 12% darker. Contrast comes from the light now (a stronger sun, a weaker fill).
- **Darker cobbles** (`ccc2b0`, `b3a899`): the stones blurred into one another. The square uses `d4cab6`, `bbae9b`.

## Next steps worth trying
- **More of the look as data.** A place's `look` block already sets the grade's shade and light, the wind, the amount
  of ambient life and the falling leaves' colours, and its layout sets grass, bush and leaf colours, roof tiles and
  house style, valley fog and the horizon (`docs/WORLD.md`). Grade keyframes and the bounce light's colour could
  follow, so Clockwork Cove can have brassy evenings and a misty blue night with no new code.
- **Settings toggles** for depth blur, cloud shadows and ambient life on slower machines (next to the outline toggle).
- **Lit materials for small creatures.** Butterflies use an unlit material, so at night they glow like fireflies.
  Anything that should darken after dusk needs a lit material (or should go to bed at night).
- **Clouds with sunlit edges** and a soft horizon glow in the sky shader.
- **Screen-space indirect light (SSIL)** for colour bleeding from walls onto paths (Forward+ only, costs frame time).
- **Footprints and paths that wear in** where villagers walk, as terrain decals.
- **Hand-modelled hero assets** (Blender, exported as glTF) if the procedural shapes ever feel limiting. This changes
  how models are made, so it is a project of its own.

## How it was checked
- Tonemapping and light (07/11): `godot/views.sh` before and after in Forward+ on software Vulkan, measured with
  `godot/measure_views.py`. Contrast rose 15 to 55% in every view; clipped white fell from 6.2% to 0.5% in the sunset
  view and to at most 1.6% elsewhere (bright sky); daytime views are 5 to 11% brighter (the gain is in the
  highlights), golden hour and rain within 5%, night 15% darker (a moonlit blue, lamps and windows still warm). Three
  views in the compatibility renderer stay within 4% of their old brightness. Not seen on a real monitor or GPU.
- Ten fixed views (morning square, wide noon, grove, river, cottage close-up, golden hour, sunset backlight, night,
  rain, dawn mist) rendered before and after in Forward+ (software Vulkan), compared side by side with FFmpeg, with
  average ground colour measured so the grade doesn't drift.
- A motion reel recorded with Godot's Movie Maker (`--write-movie`, fixed 30 fps) for wind, water, particles and rain.
- The compatibility renderer was rendered too, to check every shader compiles there.
- The branch was trial-merged with the Clockwork Cove work (no conflicts; all 79 tests pass on the merge) and five
  Cove views were rendered before and after: the same treatment applies there without any island-specific code.
- `godot/run_tests.sh` includes `test_atmosphere.gd`: every shader global is declared with the right type, the grade
  never flips a colour, and wind and ambient life follow the hour and weather.
- **Not checked:** frame rate on real graphics cards (the test machine renders in software), and how it feels in play
  over a long session.
