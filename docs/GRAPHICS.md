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
9. **Grade gently.** A colour grade sets the mood of each hour (rosy dawn, neutral noon, warm dusk, blue night), but
   strong highlight tints dull saturated greens and kill the warmth of lamp light. Keep highlights close to white and
   tint mostly the shadows.
10. **Use distance for mood.** Haze (fog) and a slight blur on the far distance make an island read like a miniature
    diorama and keep attention near the player.
11. **Ambient life carries the atmosphere.** Dust motes in sunshine, fireflies on dry nights, leaves falling from the
    nearest real tree and drifting downwind: small, cheap, tied to the hour and the weather.
12. **Check your own work in pictures and motion.** Render the same views at the same hours before and after a change,
    compare them side by side, measure average brightness so a grade doesn't drift, and record a short clip, because
    wind, glitter and particles only show in motion.

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
| Colour grade that follows the hour and weather | `atmosphere.gd` (environment colour correction) | all |
| Cloud shadows matching the sky's clouds, soft vignette | `atmosphere.gd` (screen pass) | Forward+ |
| Slight blur on the far distance | `atmosphere.gd` (camera attributes) | Forward+ |
| Dust motes, fireflies, falling leaves | `atmosphere.gd` (GPU particles) | all |

The atmosphere module only reads the clock, the weather and the player's position. It does not touch rules, saves or
layouts, and the game loads it the same way as the animals module.

## Tried and dropped
- **Normal maps from the detail textures** (plaster, wood, stone, fabric). Invisible at gentle strengths, and at
  visible strengths the rim light made surfaces lighter and flatter. Fabric relief also broke on character meshes that
  have vertices without a usable normal.
- **A strong colour grade.** The first version tinted highlights warm and lifted shadows by up to 8%: sunsets turned
  olive and night lamps lost their warmth. The current grade stays within a few percent of neutral.

## Next steps worth trying
- **A look per island, as data.** Grade keyframes, wind strength, bounce colour and particle colours could live in each
  island's layout file, so Clockwork Cove can have brassy evenings and Moonveil Hollow a misty blue night, with no new
  code.
- **Settings toggles** for depth blur, cloud shadows and ambient life on slower machines (next to the outline toggle).
- **Clouds with sunlit edges** and a soft horizon glow in the sky shader.
- **Screen-space indirect light (SSIL)** for colour bleeding from walls onto paths (Forward+ only, costs frame time).
- **Footprints and paths that wear in** where villagers walk, as terrain decals.
- **Hand-modelled hero assets** (Blender, exported as glTF) if the procedural shapes ever feel limiting. This changes
  how models are made, so it is a project of its own.

## How it was checked
- Ten fixed views (morning square, wide noon, grove, river, cottage close-up, golden hour, sunset backlight, night,
  rain, dawn mist) rendered before and after in Forward+ (software Vulkan), compared side by side with FFmpeg, with
  average ground colour measured so the grade doesn't drift.
- A motion reel recorded with Godot's Movie Maker (`--write-movie`, fixed 30 fps) for wind, water, particles and rain.
- The compatibility renderer was rendered too, to check every shader compiles there.
- `godot/run_tests.sh` includes `test_atmosphere.gd`: every shader global is declared with the right type, the grade
  never flips a colour, and wind and ambient life follow the hour and weather.
- **Not checked:** frame rate on real graphics cards (the test machine renders in software), and how it feels in play
  over a long session.
