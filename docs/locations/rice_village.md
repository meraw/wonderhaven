# Casalrana: design for the rice village

Working id `rice_village`. Agreed with the user on 2026-11-04 in a design interview. **Stages 1 to 3 (ground and
map; buildings and scenery; people, dialogue and requests) are built**; stage 4 is not. This doc is the plan the build stages follow. The rules every location shares are in `docs/WORLD.md`; `docs/MONTEFORCHETTA.md`
and `docs/locations/metropolis.md` are the models this doc follows.

## The concept
Casalrana Vercellese is a hamlet out on the rice plain near Vercelli, in late November going into early December,
around the year 2000. The rice was harvested in the autumn and the plain has gone quiet: golden stubble, puddles that
mirror the sky, bare poplars, frost at dawn, and the main railway line roaring past the village without stopping.

The player comes here after Monteforchetta and the river town, and before Toriano. The regional train stopped
stopping at Casalrana's little station in 1993, when the station went unmanned. Paletta, the retired station master,
has written to the province asking for a Geometra to save it. The new Geometra arrives on the bus, lives in the flat
above the station, helps the village through the start of winter, and the main story ends when the first regional
train in years stops at Casalrana. That opens the line to Toriano.

- **Feel:** clear, bright white winter skies and a low sun; frost on the stubble; brick and cobble farmsteads; rows of
  bare poplars; herons standing in the ditches; the crossing bells and the rush of a passing train.
- **Running gags:**
  - **The trains that don't stop.** Paletta raises his signal paddle at every one of them. Passengers drop things out
    of the windows as they go by.
  - **The frogs.** The village is named after them (*rana* means frog), and they are all asleep in the mud until
    spring. People talk about them like relatives who have gone away for the winter.
  - **Herons on a subsidy.** Barba Tista is paid by Brussels to flood a paddy for the winter birds, and nobody, least
    of all him, quite believes it.
  - **The petition.** The village has 41 inhabitants. The railway wants 250 signatures. Paletta has a plan for the
    other 209.
  - **No signal.** Silvia's mobile phone works in exactly one place in Casalrana: the top of the bell tower.

## Ground rules for Casalrana
- **Size:** a village map, the default 124 m square, a short walk end to end.
- **Season:** late November into early December. There are no dates, except that the living nativity happens "on
  the 8th".
- **Weather:** always clear. Pale, white-bright skies every day, frost at dawn, no fog and no rain.
- **Money:** lire, with country prices.
- **Language, names, originality, no magic:** as in `docs/WORLD.md`. In the game's text the farmstead is "the
  farmstead" (its name is Cascina Grande), the spring pool is "the spring pool", and so on; Italian is kept for names,
  job titles and honorifics (Capostazione, Fattore, Perita agraria, Don, Nonna, Ingegner, mondina). Casalrana, its
  church, its farmstead, its mill and its station are invented; the railway is simply "the main line".

## The place
North is up (towards negative z in the game).

```text
            N
 +--------------------------------------+
 | ====== railway on embankment ======= |
 |  [casello]  X crossing   [STATION]   |
 |     |      |            platform     |
 | canal      |                         |
 | |sluice  paddy | paddy  | paddy      |
 | |          |  road   |               |
 | |[MILL]  --+-- CROSSROADS --+--      |
 | |  flooded | [CHURCH]  |  [CASCINA]  |
 | |  paddy   | + tower   |  courtyard  |
 | |          |   bus o   |  barns,     |
 | | paddy    |  paddy    |  dryer      |
 | |  ~fontanile~  |  paddy  | paddy     |
 | |  (grove)  | poplar plantation       |
 +--------------------------------------+
  white haze and paddies to the horizon
```

| Area | What's there |
| --- | --- |
| The railway (north edge) | The double-track main line on a low embankment with scrubby robinia, and leaning old telegraph poles with glass insulators. **The station:** a two-storey building in faded railway ochre with dark red trim, a platform canopy on cast-iron columns, a crumbled platform, a payphone and the flower beds Paletta has kept for thirty years. The waiting room is downstairs; your flat is upstairs. **The level crossing** where the road meets the line, with barriers, bells and red lights. **Paletta's crossing keeper's cottage** (*casello*) on the west side of the crossing. |
| The crossroads (centre) | The road runs south from the crossing to the crossroads. **The church of San Grato** in bare brick, with a tall, slim bell tower and a pointed top: the tallest thing for miles. The presbytery beside it, and the churchyard where the nativity stable goes. **The bus stop**, where you arrive and where the bus leaves. |
| Cascina Grande (east) | The walled courtyard farmstead and the heart of the village. The farmhouse where the Mosso family lives (Nonna's kitchen), the farm office (Silvia's shop), the machine shed (Barba Tista's shop) with a rusting threshing machine beside it, open barns with brick latticework in their gables, the cowshed with the cows, the ox and the donkey, the brick drying yard where rice was once spread, a tall metal rice-dryer tower, and a row of farm workers' houses standing empty since machines replaced the workers. A vegetable garden with the garden beds. Chickens and cats. |
| The canal (west) | The irrigation canal, **drained for its winter repairs**: a muddy bed with puddles, and river cobbles dredged from it heaped along the banks. **The collapsed sluice gate** where a side ditch takes water off to the paddies. **The old rice mill**, a small brick mill (*pila*) with a stopped waterwheel. **The winter paddy** beside the canal, dry until Barba Tista's request floods it. |
| The spring pool (south-west) | A *fontanile*: a pool fed by a spring, whose water stays mild all winter, so it steams on cold mornings and never freezes. In a small grove of willows and alders. Fishing. |
| The poplar plantation (south) | Straight rows of poplars grown for timber, where you chop wood. At its edge, the paddy where Nonna weeded in 1951, where her bench goes. |
| The paddies (everywhere between) | Harvested stubble in pale gold-brown with puddles that mirror the white sky, frosty at dawn, thin ice on the puddles in the early hours. A grid of raised grassy banks between them. Straw to gather on some, herons in the ditches, lapwings on the stubble. |
| The edge | Paddies and rows of poplars running on into a bright white haze, with faint farmsteads and the bell towers of the next villages. No mountains. |

The invented names the user didn't choose (San Grato, Cascina Grande) can change.

## Getting there and around
- **Arrival by bus.** Aldo's bus, on the line Monteforchetta's finale opens, brings you on from Boccapioppo and stops at
  the crossroads on its way across the plain. Paletta is waiting. (The travel order, as the user decided: Monteforchetta,
  Boccapioppo, Casalrana, Toriano. Boccapioppo's finale sets `rice_village_revealed`.)
- **The departure point** is the bus stop: a feature of kind `boat` (`rice_village_busStop`, "Catch the bus"), as
  `docs/WORLD.md` asks. Its boat model stays hidden; a bus stop sign stands there instead.
- **Out by train.** The finale gets the regional train stopping again. From then on the station platform is a second
  departure point, the one for Toriano. Casalrana's finale sets `rice_village_trainStops`, the flag Toriano's map
  entry reveals on (agreed: Toriano's entry already waits for it).
- **Until then,** Casalrana stays off the travel map (its entry shows once `rice_village_revealed` is set). Tests reach
  it with `--island=rice_village`, and the playthrough starts as if Monteforchetta and Boccapioppo had been played
  (`arrive_as_if_played(["hearthglow", "river_town"])`).
- **On foot.** You walk the road and the banks between the paddies. The harvested paddies are walkable stubble. The
  canal, the flooded paddy and the spring pool are water. The railway is fenced off by its embankment, except at the
  level crossing.
- **The trains.** A busy main line: a train every half hour or so of game time. Red-and-white regionals, white-and-green
  intercity expresses, long freight trains, a night express (only at night) and a bright yellow track inspection train
  (only at dawn). The crossing bells ring and the barriers drop and close the road, Paletta raises his paddle, and the
  train roars past. The barriers keep the player and villagers off the line while a train is coming.

## Look
- **Buildings:** the rice country's own brick and cobble. The farmstead and the mill in exposed red brick, with walls of
  river cobbles laid in herringbone, and open barns with brick latticework in their gables. Houses plastered in faded
  ochre and cream with green shutters, and curved terracotta roof tiles. The church in bare brick with a tall, slim
  tower and a pointed top. The station in faded railway ochre with dark red trim and its canopy on cast-iron columns.
  The metal rice-dryer tower at the farmstead. Paletta's cottage in the same railway ochre as the station.
- **Ground:** pale golden stubble with puddles that mirror the sky; grassy banks, frosted white at dawn; white gravel
  roads; the farmstead's brick drying yard; the canal's drained mud bed. No meadow flowers: it's winter.
- **Plants:** bare poplars in straight rows, a few with balls of mistletoe (scenery only; gathering it was offered and
  not chosen); willows and alders round the spring pool; robinia scrub on the railway embankment; a few old mulberry
  trees along the field edges; box hedges and one cypress by the church; cabbages and leeks in the farmstead's garden
  beds; hellebores along the churchyard wall.
- **Animals:** grey herons standing motionless in the ditches and the flooded paddy, with white egrets among them, taking
  off with a croak when you come close; flocks of lapwings wheeling up from the stubble; now and then a V of cranes
  passing high overhead. At the farmstead: cows, the ox and the donkey, chickens and cats. No frogs (asleep in the
  mud) and no mosquitoes (gone for the winter, the one thing about December everyone likes).
- **Light:** always clear. A pale, white-bright sky, a low winter sun and long shadows. Hoarfrost whitens the stubble
  and the banks at dawn and melts by late morning, and the puddles carry thin ice in the early hours. Clear, starry
  nights with frost again. At night the station lamps, the red lights of the crossing and the farmstead's windows. The
  clock's parts of the day and the hours of requests stay as in every location.
- **The look block** (`location.json`): cool shadows, highlights close to white, very little wind, motes in the low sun,
  no fireflies, and only the rare falling leaf.

## Sound
- **Music:** sparse and quiet. Soft themes for each part of the day in the game's procedural music system, with long
  pauses between phrases so the sounds of the plain carry. (A wintry pop with an accordion lead, and Monteforchetta's
  sound, were offered and not chosen.)
- **Trains and the crossing:** the crossing bells as the barriers drop, the horn, the rumble and rush of a train going
  by, then quiet again.
- **Birds:** herons croaking as they take off, the lapwings' peewit calls, the trumpeting of cranes passing over.
- **Church bells for big moments only:** a peal when the tower stairs are finished, at the living nativity and in the
  finale. No hourly bells.
- Frost underfoot and farmstead sounds (cows, a tractor) were offered and not chosen.

## The cast
Six villagers. Ids are `rice_village_<first name>`, for example `rice_village_ernesto`. Barba Tista, Nonna Pierina,
Silvia and Matteo are one family at Cascina Grande: Nonna is Barba Tista's mother (Italian women keep their own
surname), Silvia is his niece and Matteo his grandson. Paletta and Don Remo are the outsiders.

| Who | Where | Who they are | Outfit |
| --- | --- | --- | --- |
| **Capostazione Ernesto "Paletta" Tarditi** | The station platform; his crossing keeper's cottage | The retired station master. The station went unmanned in 1993, but he still comes every morning in uniform and raises his signal paddle (the *paletta*) as trains thunder through. He wrote to the province asking for a Geometra. Meets your bus and runs your first day, with a story about every train that hasn't stopped since 1993. Keeps the station's flower beds and the railway's forgotten storeroom. | Railway cap and coat, the red-and-green signal paddle |
| **Battista "Barba Tista" Mosso**, the Fattore | The fields in the morning; the machine shed in the afternoon | Runs Cascina Grande for an owner nobody has seen since 1974 (*Barba* is Piedmontese for uncle). Gruff, reads the sky like a newspaper, and is deeply suspicious of all this clear weather. His tractor is older than he is. Gets paid to grow herons. | Quilted gilet, flat cap, rubber boots |
| **Nonna Pierina Avondo** | The farmhouse kitchen; the vegetable garden | Barba Tista's mother, 81. Weeded these paddies by hand as a mondina in 1951 and still sings the work songs. Makes the salami kept in fat in a clay pot, Vercelli's spiced Christmas biscuits and a pot of panissa big enough for the village. Remembers everyone's grandparents and their mistakes. | Black shawl, headscarf, apron |
| **Silvia Bonino**, Perita agraria | The farm office in the morning; the old mill in the afternoon | Barba Tista's niece, back from agricultural college with big ideas: restart the old mill and sell the village's own rice in cloth bags. Practical, drives the tractor, argues with Nonna about everything and agrees with her on everything important. Owns a mobile phone with no signal. | Fleece jacket, wellies, a ring binder |
| **Don Remo Avetta** | The church and presbytery; away on his small motorbike some afternoons | The parish priest, who covers four other villages too. Wants the bells rung by hand for Christmas and directs the living nativity. Secretly the best bocce player in the province. | Cassock, scarf, motorbike helmet |
| **Matteo Mosso** | The level crossing, the station, the banks on his BMX | Barba Tista's grandson, 10, staying with Grandpa while his parents work in the city. Writes down the number of every train that passes. Paletta's only staff. Keeps a "museum" on a shelf in the waiting room. | Puffy jacket, woolly hat, a notebook |
| **Ingegner Carlo Pautasso** (a visitor, not a villager) | Only in the finale | The railway's inspector. Arrives in a small boxy service car with a clipboard and a thermos, sets three conditions, and comes back for the first stopping train. No routine, topics or gifts. | Grey suit, railway anorak over it, clipboard |
| **The player** | | The Geometra, sent by the province at Paletta's request. | The windbreaker and clipboard, plus Casalrana's clothes below |

Daily routines are drafted in stage 3. In outline: Paletta is on the platform from the first train until dusk, then in
his cottage; Barba Tista in the fields in the morning and the machine shed in the afternoon; Nonna in her kitchen with
a turn in the garden at midday; Silvia in the farm office, then at the mill; Don Remo at the church, sometimes away on
his motorbike in the afternoon; Matteo doing homework in the waiting room, by his museum shelf, in the morning and at the crossing in the
afternoon, home by dark.

## The petition: Casalrana's progress meter
Requests in Casalrana bring in **signatures on Paletta's petition to the railway** instead of raising the Sindaco's
approval rating, which stays Monteforchetta's. Each request finished spreads the word across the plain, and the
signatures come from the next villages, the bus passengers and Matteo's whole school. Main requests bring more than side
requests. About 320 are on offer and the finale needs 250, so the main story plus three or four side requests fill it.

| Request | Signatures |
| --- | --- |
| Welcome to Casalrana | 20 |
| The Flat above the Station | 30 |
| The Bell Tower Stairs | 60 |
| The Living Nativity | 60 |
| Water for the Winter, The Old Rice Mill | 30 each |
| Matteo's Train Log, Things from the Trains | 25 each |
| Nonna's Bench, Matteo's Museum | 20 each |

The milestones' rewards are practical:

| Signatures | Milestone | Reward |
| --- | --- | --- |
| 40 | The first full page | 30,000 lire for "expenses" |
| 90 | Two pages, one in pencil | The old goods yard beside the station becomes part of your build plot |
| 140 | The province takes note | A load of materials: 10 wood, 8 stone, 4 metal, 2 copper wire |
| 200 | A rubber stamp from the next village | 100,000 lire |
| 250 | The petition is full | The finale's third condition is met |

## Gathering
| Material | Where it comes from |
| --- | --- |
| Wood | Chopping poplars in the plantation (the chopping minigame). |
| Stone | River cobbles dredged from the drained canal bed and heaped on its banks (the quarrying minigame). The old walls are built from them. |
| Clay | Dug from the ditch banks. |
| Rice straw | Loose straw and small bales on the harvested stubble. A new material, `rice_village_straw`. |
| Winter vegetables | Cabbages and leeks grown in the farmstead's garden beds, from seed packets Silvia sells. New items. |
| Fish | The spring pool: tench and carp, and once in a while a sleepy frog you put straight back. |
| Flowers | Hellebores along the churchyard wall. |
| Metal | Only from Barba Tista's shop (old parts from the machine shed). |
| Copper wire | Only from Paletta's shop (spools from the railway storeroom he insists the railway forgot it owned). |
| Fabric | Only from Silvia's shop (cloth rice bags and old linen). |
| Lost things | Things dropped from the windows of passing trains, along the line: a hat, a newspaper, a glove, a cassette, an umbrella. The shared lost things. |
| Metal detector finds | With your own metal detector, the shared one you carry everywhere: an old coin, a mondina's tin badge and railway buttons in the stubble. Casalrana items, for Matteo's museum. |
| Treats | Panissa, the spiced Christmas biscuits, salami kept in fat, and hot vin brulé at the nativity and the finale. |

## Shops
| Shop | Sells | Buys |
| --- | --- | --- |
| Barba Tista (the machine shed) | Wood, straw, sacks of rice, metal | Straw, vegetables, fish |
| Silvia (the farm office) | Vegetable seed packets, young poplars, building plans, fabric, Nonna's treats (panissa, biscuits, salami: Nonna makes them and keeps the recipes secret), and Casalrana rice in cloth bags once the mill runs | Nothing: Barba Tista buys for the farmstead |
| Paletta (the station storeroom) | Copper wire, the station master's cap, a railway lantern and old enamel railway signs for your flat | Nothing: "The railway doesn't buy. It barely sells." |

## Clothes
| Clothes | How you get them |
| --- | --- |
| Station master's cap | Paletta's shop. |
| Wool hat and scarf | Knitted by Nonna Pierina as a friendship gift, in colours she chooses without asking you. |
| Green rubber boots | The reward for Water for the Winter. |

## Requests
Ids are `rice_village_<name>`. As everywhere, construction requests check what you built, not one layout.

### Main story
| # | Request | Given by | What you do |
| --- | --- | --- | --- |
| 1 | **Welcome to Casalrana** | Paletta | He meets your bus at the crossroads and walks you up the road to the station, with a story about every train that hasn't stopped since 1993. The level crossing (wait for the barriers), the family at the farmstead, Don Remo, a little wood and stone to gather, and the keys to the flat. Until it's fit to sleep in, you sleep on the waiting-room bench. This is Casalrana's first day: a request in steps, with his commentary to skip through. |
| 2 | **The Flat above the Station** | Paletta | The flat is free because the roof leaks. Gather clay for tiles and wood for battens, patch the roof, then furnish the basics: a bed, a table, a chair and a lamp. The flat becomes your home (bed and wardrobe), and the station's yard your build plot. |
| 3 | **The Bell Tower Stairs** | Don Remo | The wooden stairs inside the bell tower have rotted, and he wants the bells rung by hand for Christmas. Gather poplar wood, then build a climb you can really walk up, from the tower's floor to the bell chamber. Any continuous climb counts. At the top, ring the first peal together. Silvia discovers her phone has signal up there. |
| 4 | **The Living Nativity** | Don Remo | Every 8 December the village stages a living nativity, but the stable blew down. Gather rice straw and wood, then build a new stable in the churchyard: posts or walls, a roof, the straw (hand it to Don Remo) and two lamps. On the evening of the nativity the village plays it straight, and it's lovely: candles, the farmstead's ox and donkey, Nonna singing an old carol, the bells, and vin brulé afterwards. |
| 5 | **The Train Stops Here**, the finale | Paletta | In steps. Ingegner Pautasso arrives with three conditions. **The platform:** rebuild the crumbled platform as one continuous walkable platform along the track, from the station door to the far end of the platform site; any continuous, supported path counts. **The shelter:** a lit shelter on the platform with a roof, a bench, two lamps and a sign. **The petition:** 250 signatures. Then, the next morning, the first regional train in years stops at Casalrana: the whole village is on the platform, Paletta raises his paddle for real, the bells peal, and there is vin brulé. Toriano opens on the travel map. |

### Side requests
| Request | Given by | What you do |
| --- | --- | --- |
| **Water for the Winter** | Barba Tista | The canal is drained for its winter repairs and its old sluice gate has collapsed. Gather cobbles and wood, then rebuild the sluice: two stone pillars, a gate lever and a walkway across. The canal fills. Then flood the winter paddy for the birds: a waterwheel in the canal drives a pump, and pipes carry the water to the paddy's inlet (a machine target, `fed:rice_village_paddy`). The paddy turns into a mirror and the herons and egrets arrive. Barba Tista explains the subsidy and doesn't believe it either. Rewards include the green rubber boots. |
| **The Old Rice Mill** | Silvia | Offered once the canal is full. Gather wood and buy metal, then put a waterwheel in the mill race and drive the old mill's machinery through shafts and gears (`fed:rice_village_mill`). The mill husks the farmstead's rice into the first cloth bags of Casalrana rice, which Silvia sells from then on. |
| **Nonna's Bench** | Nonna Pierina | She wants a bench under the poplars at the edge of the paddy where she weeded in 1951, with a flower bed beside it. Then sit with her there at dusk, and she sings one of the old work songs. |
| **Matteo's Train Log** | Matteo | Stand at the level crossing and note down five different trains for his log: a regional, an intercity, a freight train, the night express (only at night) and the yellow inspection train (only at dawn). |
| **Things from the Trains** | Paletta | Passengers drop things out of the windows of trains that don't stop. Find five along the line (a hat, a newspaper, a glove, a cassette, an umbrella) and bring them to his lost-property cupboard, for thanks and a story about each. |
| **Matteo's Museum** | Matteo | Use your metal detector in the stubble to find three things for his museum in the waiting room: an old coin, a mondina's tin badge and some railway buttons. He writes a label for each. |

Five main and six side requests.

## Rooms you can walk into
- **The station:** the waiting room (the bench you sleep on at first, the lost-property cupboard, Matteo's museum shelf,
  the ticket window shuttered since 1993) and your flat upstairs.
- **Paletta's crossing keeper's cottage.**
- **Cascina Grande:** the farmhouse kitchen (Nonna's stove, the panissa pot and the family's long table), Silvia's farm
  office and Barba Tista's machine shed.
- **The church:** the plain brick nave with candles, and the inside of the bell tower for the stairs.
- **The old mill**, with its machinery.
- Not the barns, the presbytery or the empty workers' houses.

## Changes to shared code this needs
Each is the smallest general version, comes with a test, and is named at the top of the pull request that makes it.
Several are also planned by Toriano (`docs/locations/metropolis.md`): whichever session gets there first builds it, and
the other merges main and reuses it.

| Change | Why | Stage | Also in Toriano's plan |
| --- | --- | --- | --- |
| **Weather per location:** which weather types a location can have, in its `look` block (here only clear) | Always clear | 1 (built) | No |
| **Ground paint from the location script:** `paint(x, z)` colours the ground point by point and says where meadow grows (clover, flowers, grass tufts, bushes, trees). Toriano built paving laid out as shapes (`ground` in a layout); this is the other half, for fields | Stubble, banks of winter grass, mud and a brick yard instead of meadow | 1 (built) | Toriano built the paving half |
| **A building's height in the layout** (`h`), which the camera keeps clear of | The low railway bed, the tall bell tower | 1 (Toriano's, reused) | Built by Toriano |
| **Raised floors** in a layout that you can walk and build on | The flat upstairs and the bell chamber | 3 (moved from 2, to reuse Toriano's if it lands first) | Yes |
| **A path check for any zone** (`path:<zone>`), with endpoints that may be at different heights | The platform, and the climb up the tower | 3 (built) | Yes |
| **Garden beds from the layout**, each with its crop (today there are four fixed beds that grow pumpkins) | Cabbages and leeks at the farmstead | 3 (built) | No |
| **What a gathering spot gives, from the layout** (`items`, `label`, `found`; today metal detector finds come from a fixed list) | Matteo's museum finds, loose straw, the lost things' names | 3 (built) | Similar (Roman finds) |
| **What fishing catches, per location** | Tench, carp and the sleepy frog | 3 (built) | Yes |
| **A location's own progress meter** (name, unit, milestones), fed by that location's requests | The petition | 3 (built) | Yes |
| **Two new building pieces:** a railway lantern and an enamel railway sign | Paletta's shop | 3 (built) | No |
| **Rooms on raised floors in play:** a room's roof fades on its own storey, a room can be tall, build mode aims at raised floors, and placed furniture is used from its own storey | The flat upstairs, the bell tower | 3 (built) | Yes (rooms upstairs) |
| **A location's own music** (its own tune for each part of the day) | Sparse, quiet themes | 4 | Yes (its own themes) |
| **Clothing variants:** an unlockable item that reuses an existing shape with its own colours | The station master's cap, Nonna's hat and scarf, the green boots | 4 | Similar (new clothing shapes) |

Everything else lives in Casalrana's own files (`docs/WORLD.md`): `godot/data/locations/rice_village/`,
`godot/scripts/locations/rice_village.gd` and helpers in `godot/scripts/locations/rice_village/`,
`godot/tests/test_rice_village.gd` and `godot/tests/play_rice_village.gd`. The trains, the crossing barriers, the canal
filling and the paddy flooding are location code; the barriers keep people off the line through `WalkWorld`'s moving
bodies.

## Build stages
One pull request per stage. Each keeps the game playable and the tests passing.

1. **Ground and map.**
   - The shared weather-per-location and ground-paint changes, unless Toriano has built them by then.
   - The ground shape: the flat plain, paddies on a grid of banks with mirror puddles, the canal and the winter
     paddy, the spring pool, the railway embankment.
   - The layout: the bus stop as spawn and arrival, the departure point, the nav graph, paths, build zones and the
     station's yard as your plot.
   - A hidden map entry and a first `look` in `location.json`.
   - Plain boxes for the buildings so the map reads in screenshots.
   - `test_rice_village.gd`: a playable world (the arrival is walkable, every nav spot is reachable, water where the
     canal and pool are, build zones on dry ground).
2. **Buildings and scenery.**
   - Models for the station with its canopy and platform, the crossing and Paletta's cottage, the church and its tower,
     Cascina Grande (farmhouse, barns with brick latticework, the dryer tower, the drying yard, the machine shed, the
     workers' row), the old mill and its waterwheel, the collapsed sluice.
   - Rooms you can walk into, with furniture and routes. (The raised-floors change for the flat and the bell chamber
     moved to stage 3, where the Flat and the Bell Tower Stairs need it, so it can reuse Toriano's if it lands first.)
   - The trains on their timetable, with the crossing's bells, lights and barriers.
   - Poplar rows, willows and alders, robinia, mulberries, telegraph poles, straw bales, and the edge: paddies and
     poplar rows fading into the white haze, with distant farmsteads and bell towers.
3. **People, dialogue and requests.**
   - The six villagers with routines, greetings, topics and gifts, and Ingegner Pautasso for the finale.
   - The eleven requests, the three shops, Casalrana's items and the petition.
   - The canal filling and the paddy flooding.
   - The shared path check, garden beds, metal detector finds, fishing catches, petition meter and the two pieces.
   - `play_rice_village.gd`: a scripted playthrough of every request with real input.
4. **Look and ambient life.**
   - Tuning the look block; frost at dawn and thin ice on the puddles; the low sun.
   - Herons and egrets, lapwings, cranes overhead, and the farmstead's animals.
   - The music and the sounds of the trains, the crossing, the birds and the bells.
   - The cast's outfits and Casalrana's clothes.

## Risks
- **Water that changes in play.** The canal fills and the winter paddy floods during a visit, but the ground's shape is
  fixed. The plan: both beds are water underneath from the start, covered by a dry mud or stubble surface until their
  request fills them. Nobody walks in them before or after, so walking and building don't change.
- **Upstairs rooms and the tower climb** depend on raised floors and a path check that climbs, both shared and both
  also Toriano's. If raised rooms prove too hard, the flat moves into the station's ground-floor end wing and the tower
  climb becomes a stair scaffold up the outside of the tower; the user is asked first.
- **Trains** are long and fast. The barriers must close early enough that no one is ever on the line when a train
  passes, and long trains must not cost too much frame time. Measured before and after stage 2.
- **A white sky and frost** can wash the picture out. Average brightness is measured in screenshots, as
  `docs/GRAPHICS.md` describes.
- **Links to other locations.** Arriving depends on Monteforchetta's bus and travel stops; leaving by train depends on
  Toriano's map entry using Casalrana's flag. Both are agreed with those sessions, not changed in their files.

## Status
**Stage 1, ground and map: built.**
- **The ground** (`godot/scripts/locations/rice_village.gd`):
  - Harvested paddies on a grid of banks, with 34 puddles that mirror the sky.
  - The drained canal (a muddy bed with puddles) and the sunken, dry winter paddy.
  - The spring pool in its green grove, the railway bed, and flooded paddies past the edge.
  - Painted stubble, banks, gravel, brick and ballast.
- **The layout** (`godot/data/locations/rice_village/layout.json`):
  - The bus stop where you arrive (the departure point), 43 nav spots, paths, four benches, signs and a notice board.
  - Basic gathering: poplars, cobble heaps, clay, the spring pool, hellebores.
  - Seven build sites. Your yard opens with `rice_village_homePlot`; the six request sites open with requests that
    stage 3 adds.
- **The map entry:** off the map until revealed, with an always-clear look.

**Stage 2, buildings and scenery: built** (helpers in `godot/scripts/locations/rice_village/`).
- **Buildings** (`buildings.gd`, with Casalrana's own brick, herringbone cobble and brick-lattice textures in
  `textures.gd`):
  - The station in railway ochre with dark red trim, green shutters, the name boards, a stopped clock and the canopy
    over the platform.
  - Paletta's cottage, the presbytery, the bare brick church (pilasters, round window, portal, arched windows) and its
    bell tower (clock faces, open bell chamber with its bell, eight-sided spire).
  - The old mill, with its rusty shaft and broken waterwheel.
  - Cascina Grande: the farmhouse with its wooden balcony, the farm office, the shut-up workers' row with its outside
    stair, the machine shed, the cowshed with its latticework hayloft, the open barn full of straw, the metal rice
    dryer, and the herringbone cobble walls with the brick gateway.
  - Barba Tista's tractor and the old threshing machine.
- **Rooms you can walk into**, with furniture and a spot for whoever works there: the station's waiting room (where
  you sleep on the bench for now), Paletta's cottage, the church, the mill, the farmhouse kitchen, the farm office and
  the machine shed. The flat upstairs and the bell chamber wait for stage 3.
- **Trains** (`timetable.gd`, `trains.gd`): a deterministic timetable of regionals, intercity expresses, freight
  trains, the night express and the dawn inspection train, a train every 30 to 44 game minutes. The level crossing's
  barriers come down four minutes before each one, the red lamps blink, and while it's closed the crossing is blocked
  (anyone on it steps back off). Windows and headlamps light up at night.
- **Scenery** (`scenery.gd`): bare poplars (the plantation's gathering spots too), pollarded willows and alders round
  the spring pool, robinia on the railway bed, old mulberries, round straw bales, the payphone, lamp posts, Paletta's
  flower beds, the telegraph line and the overhead wires, the collapsed sluice, the bus stop sign.
- **Past the edge:** a grid of banks across the flooded plain, rows of poplars, the railway on its embankment, and
  eight distant farmsteads, four with bell towers.
- **Verified:** see the stage 2 pull request; the walk-through also goes into every room and waits at the crossing
  for a train.
- **Not yet:**
  - The flooded plain is still the shared water's bright blue; it gets a paddy-water tint with the look in stage 4.
  - The haze is the shared one; the white haze comes with the look in stage 4.
  - The upstairs flat and the bell chamber, which need raised floors (stage 3).

**Stage 3, people, dialogue and requests: built.**
- **The people** (`npcs.json`): Paletta, Barba Tista, Nonna Pierina, Silvia, Don Remo and Matteo, each with a routine
  (some change as requests are done), greetings, topics and a friendship gift; Ingegner Pautasso turns up for the
  finale only. Paletta waits at the bus stop until he's welcomed you.
- **The requests** (`quests.json`): all eleven, as the table above describes. Paletta's petition is Casalrana's
  meter (`location.json`): every request adds signatures, and its milestones give the expenses, the goods yard, the
  province's materials and the next village's 100,000 lire.
- **Shops and items** (`shops.json`, `resources.json`): Barba Tista, Silvia and Paletta's storeroom; straw, seed
  packets, cabbages and leeks, rice, Nonna's treats, vin brulé and the museum's three finds.
- **The layout**: the flat on the station's upper storey with its outside stair and landing (raised floors); the bell
  tower as a room you can walk into, with its ringing floor; three holes in the crumbled platform; loose straw, lost
  things on both sides of the line, metal-detector finds, four garden beds, the goods yard, and the two machine
  targets (the winter paddy's inlet and the mill's drive).
- **Location code** (`village_life.gd`): the first walk to the crossing, noting trains for Matteo, patching the
  roof, pulling the bell ropes, and the canal and the winter paddy showing water once they're filled.
- **Changes from the plan:**
  - **The bell tower:** the wooden flight that rotted runs from the tower floor up to the ringing floor, 2 m up,
    where the bell ropes hang; the stone stair above it to the bells is sound. You build that lower climb. Ringing
    from the ringing floor is how real towers are rung, and it keeps the climb to a few pieces in a 4 m tower. The
    tower moved a little west and grew to 4.4 m square to fit it.
  - **The crumbled platform** has three holes that you plank over; the path check needs one continuous platform.
  - **The canal's east bank** is cut low at the winter paddy's inlet and the mill race, so a waterwheel in the canal
    can drive a pump or a shaft beside it.
  - **Moved to stage 4:** the clothes (the station master's cap, Nonna's hat and scarf, the green boots), which need
    the clothing-variants change, and so the wardrobe in your flat; the regional you see stopping at the platform
    (stage 3 tells it in the finale's dialogue); the platform as a second departure point.
- **Shared changes** (each with a test; see the stage 3 pull request): the location meter; `path:<zone>` with paths
  that climb; rooms that fade on their own storey, and tall rooms; what a gathering spot gives and what you found;
  each location's fish; garden beds from the layout; the railway lantern and enamel sign; build mode aiming at
  raised floors; placed furniture used only from its own storey; visitors who give no request of their own.

## Checks for every stage
`godot/run_tests.sh`, `npm test` and `npm run build`; screenshots of Casalrana in both renderers
(`--island=rice_village`); from stage 3, the scripted playthrough of its requests. Each pull request says what was
verified in play and what was only unit-tested.
