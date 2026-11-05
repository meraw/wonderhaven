# The world: north-west Italy, around the year 2000

Shared rules for everyone building a location, people and Claude sessions alike, often several at once.
`docs/MONTEFORCHETTA.md` is the model: the first location, designed with the user question by question.

## Setting rules
- **Feel, not documentary.** The game should feel like north-west Italy the way a Nintendo game feels Japanese.
  Plants, buildings, food, jobs and habits are based on real places, so a place reads as the Langhe, Milan or
  Liguria at a glance.
- **Era:** the late 1990s, before smartphones. Payphones, newsstands, beige computers with dial-up modems,
  cassettes, boxy TVs, scooters and small boxy cars.
- **Money:** lire. The switch to the euro happens later, in a location the user hasn't chosen yet.
- **Language:** plain English. Italian is used only for names and for job titles and honorifics: Sindaco,
  Geometra, Perito, Ragioniere, Commendatore, Nonna. No stock exclamations: they read as cringe.
- **Names:** realistic regional names, made into characters with nicknames and titles. Piedmont surnames often end
  in -o, such as Dalmasso, Barbero or Ghisolfi. Dialect nicknames help: *Barba* (uncle) in Piedmont, *Sciura*
  (the elegant Milanese lady) in Milan, *Baciccia* in Genoa.
- **Tone:** cozy with a comic streak. The full comedy layer comes later. Regional humour stays affectionate, never
  mean.
- **Originality:** characters, story, models and music are original. No real brands, real people or famous
  wineries and shops. Real places are inspiration only.
- **No magic:** the player is a Geometra, a surveyor-builder, and building is their job.

## What every location shares
- The building mode with its shared pieces, machines (waterwheels, pumps, pipes, power), gardening,
  gathering minigames (chopping, quarrying, fishing), shops and gifts, requests in steps, villager routines,
  rooms you can walk into, benches and beds, day and night, weather.
- **Shared systems change in Monteforchetta's first stage.** Spark goes, money shows as lire, Harmony becomes the
  mayor's approval rating, magic fragments become lost things, and the treasure hum becomes a metal detector.
  Design with those in mind, and merge main into your branch to pick them up.
- **Progress meter:** the approval rating belongs to Monteforchetta's mayor. If your location wants its own meter,
  ask the user first, then declare it in `location.json` (`meter`, see `LocationMeter`): requests there feed it
  with their `meter` rewards, and the HUD and progress panel show it there.
- **Travel:** Monteforchetta's finale opens the bus line to the city and the travel map. Each location has an entry
  on that map, which stays off it until the place is unlocked: every place is a surprise, and the map grows as the
  game goes on (its view widens to take in what's there). Give the entry a `reveal` flag, set by whatever opens the
  way there. For now every location needs a departure point, a feature of kind `boat`, because the islands test
  expects one. It becomes a general stop once Monteforchetta's bus is built. Transport inside a location, like
  trams or funiculars, is that location's own design; riding between its stops is shared (features of kind `stop`,
  see `Travel.stops_on`), and so are raised floors for balconies, terraces and bridges (`floors` in a layout).
- **Gathering and building checks:** a layout can say what bites there (`fish`) and what the lost things turn out
  to be (`lost`); a gathering spot can carry its own `gives`, `label`, `hours` and lines; and a
  request can check for a walkable path across any build zone (`path:<zone>`), up stairs as well as over water.
  See `godot/data/locations/README.md`.
- **Look:** shared shaders and the atmosphere module (`docs/GRAPHICS.md`) give every location wind, light,
  weather and ambient life. A location tunes its mood with the `look` block in its map entry: `shade` is added to
  shadows, `light` multiplies highlights, `wind` scales the wind, and `life` scales motes, fireflies and leaves.

## Locations
Starting points only. Each location's session settles the details with the user in its own design doc.

| Working id | Location | Status |
| --- | --- | --- |
| `hearthglow` | **Monteforchetta**, a Langhe-style hilltop vineyard village. The internal id stays for now. | Being built: see `docs/MONTEFORCHETTA.md` |
| `metropolis` | A big city like Milan: a gothic cathedral with a forest of spires and a golden statue, a glass-roofed shopping arcade, old orange trams, canals lined with bars, apartment blocks whose flats open onto shared courtyard balconies, plane trees, pigeons, grey haze, orange sodium streetlights, business suits. | Open |
| `port` | A dark port city like Genoa's old alleys: tall grimy palazzi with a slice of sky, laundry lines, grey slate roofs, black-and-white striped churches, steep stair lanes, public lifts and funiculars, a big old lighthouse, focaccia bakeries at dawn, basil in pots, capers growing out of walls, seagulls. | Open |
| `cliffs` | Cliff villages like the Cinque Terre: pastel houses stacked on cliffs, boats pulled up into the main street, terraced vineyards with tiny monorail carts, a coastal train dipping in and out of tunnels, agaves and lemons. | Open |
| `glass_island` | A glassmakers' island on a big Alpine lake, like Lake Maggiore's islands: a fishermen's island and palace gardens with white peacocks. Or a glass town inspired by Altare, near Savona. | Open |
| `alpine_village` | An Aosta-style mountain village: wooden houses, stone-slab roofs, cowbells, a creaky cable car. | Open |
| `rice_village` | A rice-field village near Vercelli: flooded paddies mirroring the sky, farm courtyards, herons, frogs, mosquitoes. | Open |
| `river_town` | A Po river town: poplars, fog, bicycles, the priest and the mayor feuding. | Open |
| `olive_village` | A Ligurian hill village with olive terraces and an old hump-backed stone bridge. | Open |
| `clockwork` | Clockwork Cove, from the old fantasy setting. Hidden from the map until it is reworked. Don't build on it. | Hidden |

## Working alongside others
1. **One location per session**, on its own branch, with one pull request per stage. Start with a design interview
   with the user, write `docs/locations/<id>.md`, and open a pull request with just that doc.
2. **Your files:**
   - `godot/data/locations/<id>/`: `layout.json` (required), plus `location.json` (map entry and `look`),
     `npcs.json`, `quests.json`, `shops.json` and `resources.json` as needed. They have the same shapes as the
     shared files and are merged in when the game loads.
   - `godot/scripts/locations/<id>.gd`, and helpers in `godot/scripts/locations/<id>/`. The script can define
     static `height(x, z)` for the ground shape, `is_stream_cell(i, k)`, `building(b)` for its own building
     models, `node(n)` for its own gathering spots, and `dress(village)` for extra scenery. See the README files
     in those folders.
   - `godot/tests/test_<id>.gd` and `godot/tests/play_<id>.gd` for your tests and playthroughs.
   - `docs/locations/<id>.md` for your design and status.
3. **Ids:** prefix every id with `<id>_`: villagers, requests, shops, materials and story flags. The tests check
   this for villagers and requests.
4. **Leave shared files alone:** the shared data files in `godot/data/`, other locations' packs, `docs/STATUS.md`
   and `docs/MONTEFORCHETTA.md`. Reuse shared code freely. If you truly need a shared change, such as a new hook or
   a bug fix, make the smallest general version, add a test, and say so at the top of your pull request. New
   building pieces are shared: ask the user first.
5. **Stay current:** merge main into your branch often. Never rebase or force-push.
6. **Before each push:** run `godot/run_tests.sh`, take screenshots of your location in both renderers, and run a
   scripted playthrough of its requests. `npm test` and `npm run build` still apply, because the web version is
   frozen but must keep building. Say what you verified in play and what you only unit-tested.

## Tools in a cloud session
- **Godot 4.4.1:** download `Godot_v4.4.1-stable_linux.x86_64.zip` from the Godot releases on GitHub into a
  scratch folder, unzip it, and set `GODOT` to the binary.
- **Forward+ screenshots** need software Vulkan: install `mesa-vulkan-drivers` with apt after `apt-get update`.
  `xvfb-run` and FFmpeg are already installed.
- **Screenshots:** `godot/shot.sh out.png --island=<id> --skiptitle --pos=x,z,yaw --cam=yaw,pitch,dist --time=H
  --weather=clear`. Add `RENDERER=forward_plus` for the game's normal look.
- **Playthroughs:** `godot/play.sh res://tests/play_<id>.gd <out_dir> --island=<id>`, with scripts built on
  `tests/autoplay_base.gd`.
- **Motion:** Godot's Movie Maker (`--write-movie out.avi --fixed-fps 30`) records smoothly even on the slow
  software renderer. FFmpeg converts the result and builds side-by-side comparisons.
