# Boccapioppo: design for the river town

Working id `river_town`. Agreed with the user on 2026-11-04 in a design interview. **Stages 1 (ground and map) and 2
(buildings and scenery) are built; stages 3 and 4 are not.** See "Build status" at the end. This doc is the plan the
build stages follow. The rules every location shares are in `docs/WORLD.md`;
`docs/MONTEFORCHETTA.md` is the model this doc follows.

## The concept
Boccapioppo is a small brick town where a clear Alpine river meets the slow brown Po, in late autumn, a few weeks
after a great flood. The river authority's levee warden has asked the province for a Geometra. You arrive on Aldo's
bus, are handed a shovel before your suitcase touches the ground, and spend your stay putting the town back
together: a new pontoon bridge, the piazza pumped dry, the dance hall reopened and finally the breach in the levee
closed before the next high water.

- **Feel:** a Po river town on the plain below the Alps: red brick and Lombard yellow plaster, poplars in
  plantation rows and tall columns, willows over the water, bicycles everywhere, the Alps sharp on the horizon in the
  clean air after the storm.
- **Running gags:**
  - **The monster catfish.** Everyone has a story about the giant catfish of the Po, a metre longer every time it's
    told. Since the flood, three people swear they saw it swimming down the main street. Old Gildo saw it in 1951;
    his nephew Mattia doesn't believe a word.
  - **Bicycles for everything.** Nobody drives. People carry ladders, cakes, a double bass and a grandmother by
    bicycle. Primo, the bike repairman, is the most important man in town.
- **Not here:** fog is Toriano's theme, so Boccapioppo has only a thin mist on the water at dawn. The brief's
  priest-and-mayor feud was dropped, and the town has no mayor at all: the levee warden runs things.

## Ground rules for Boccapioppo
- **Size:** a village, like Monteforchetta: about 100 m across, on today's 124 m ground.
- **Season:** late autumn, just after the flood. No dates.
- **Money:** lire.
- **Language, names, originality, no magic:** as in `docs/WORLD.md`. The town, its rivers, the Roman bridge and
  everyone in it are invented. Real places are inspiration only: the lower Sesia, Ticino and Po around Pavia and
  Casale.

## The place
A confluence. North is up (negative z in the game). The Alpine river comes down from the north and meets the Po, which
flows west to east along the south edge. The town is on the west bank of the Alpine river, behind a levee that runs
along the Po and turns north along the Alpine river. Across the Alpine river is the wild east bank.

```text
                              N   the Alps, snow-capped, up the valley
 +---------------------------------------------------------------------+
 | maize stubble    farm courtyard (geese)  |~~| ROMAN BRIDGE           |
 |   railway ===== STATION                  |~~|=====(hump-backed)      |
 |   column poplars along the station road  |~~|  black locust scrub    |
 |                                          |~~|  poplar plantation     |
 | PIERINA'S   church    PRIMO'S            |~~|  ^ ^ ^ ^ ^ ^           |
 |   houses    houses    workshop       |   |~~|  ^ ^  INES'S SAWMILL   |
 |   PIAZZA (flooded)  RINA'S BAR    levee  |~~|  gravel bars, boulders |
 |   arcade, payphone, sump             |   |~~|  ^ ^ ^ woods           |
 | ===== levee road ====================+   PONTOON BRIDGE site         |
 | BUS STOP  ERMES'S HOUSE    outfall       |~~|  willows, reeds        |
 | floodplain: mud, willows, BREACH         |~~|                        |
 | HOUSEBOAT  backwater  sandbank   WANDA'S DANCE HALL (on stilts)      |
 | GILDO'S SHACK    gauge post   ~~~~~~~~~~~ confluence ~~~~~~~~~~~      |
 | ~~~~~~~~~~~~~~~~~~~~~~~ THE PO (wide, slow, brown) ~~~~~~~~~~~~~~~~~ |
 +---------------------------------------------------------------------+
               far bank: poplars, then the first Apennine hills
```

| Area | What's there |
| --- | --- |
| The town (west bank) | Brick and yellow-plaster houses round a small piazza with an arcade, Rina's bar, a payphone and a small brick church (scenery only). Primo's bike workshop and Pierina's house. The piazza is the lowest part of town and is still a shallow pond, with the old drain sump at its edge. |
| North edge | The valley railway's little brick station (no ticket office: Rina sells the tickets), the track running north up the valley, an avenue of column poplars. A farm courtyard with a flock of geese among harvested maize fields. |
| The levee | A grassy embankment with a road on top, running along the Po and turning north along the Alpine river. Aldo's bus stops on it. Ermes's little red keeper's house stands on it, with the river gauge, a tall painted post, in the Po below. The breach is in the Po stretch, patched with sandbags for now. |
| The floodplain (outside the levee) | Grey flood mud, willows, the Po sandbank, a still backwater where the stranded houseboat lies, Gildo and Mattia's fishing shack by the Po, and Wanda's dance hall on stilts at the point where the rivers meet. Flood debris everywhere at first. |
| The Alpine river | Fast, clear blue-green water over white pebbles, louder than the Po. Gravel bars with big Alpine boulders. Where it meets the Po you can see the line between clear and brown water. |
| The east bank | The poplar plantation in its neat grid, Ines's sawmill with its log piles and big saw, black locust scrub, a strip of woods, the gravel bars. Reached over the Roman bridge until the pontoon bridge is built. |
| The Roman bridge | An intact, narrow, hump-backed stone bridge over the Alpine river at the north edge. Too narrow for carts and too far for daily life, so the town still wants its pontoon bridge. |
| The horizon | North, up the valley: the Alps, snow-capped and sharp on clear days, so you can see where the railway goes. East and west: flat plain, lines of poplars, the bell towers of other villages. South, across the Po: the far bank and the low first hills of the Apennines. |

**The flood, still visible:** the piazza is a shallow pond until you pump it out; grey mud lies on the floodplain;
debris and odd things sit in odd places (a fridge in a willow, a boxy little car on its roof among the poplars,
Tullio's ferry half sunk at the bank); fresh tide lines mark the walls. The piazza drains when its request is done,
debris goes as requests clear it up, and the rest of the town is dry and lived in.

## Getting there and around
- **Arrival by bus.** Aldo's bus line from Monteforchetta ends on top of the levee road. The bus stop is the
  departure point (a feature of kind `boat`, labelled as the bus, as `docs/WORLD.md` asks).
- **The travel map.** Boccapioppo has its own entry, revealed by Monteforchetta's city-bus finale (it sets
  `river_town_revealed`). Boccapioppo's own finale, Close the Breach, sends the bus line on to Casalrana: it sets
  `rice_village_revealed`. That is the travel order the user chose.
- **The valley railway** to the Alpine village starts at Boccapioppo's station: a slow two-carriage train up the
  valley. The station is a second stop on the travel map, locked until the Alpine village exists. **The Alpine
  village's session builds the top station, so this needs agreeing between the two.**
- **Crossing the Alpine river.** Tullio's ferry sank in the flood. Until the pontoon bridge is built you walk round
  over the Roman bridge at the north edge. The pontoon bridge then gives a direct crossing near the town.
- **The bicycle.** Primo rebuilds a flood-wrecked bike for you in an early side request. From then on it's yours
  everywhere bikes make sense (see below).

## The bicycle (a shared feature)
Unlocked in Boccapioppo, usable in every location that allows it, so getting it here pays off everywhere.
- **Where:** everywhere, unless a location's map entry says `"bikes": false`. The port, the cliff villages and the
  Alpine village are expected to say no; Monteforchetta and Toriano get bikes for free.
- **Riding:** one key (and a gamepad button) hops on and off anywhere outdoors. About twice running speed, with a
  gentle lean in turns. You get off by yourself to talk, build, gather, sleep or go indoors, and on stairs.
- **Upgrades** come from Boccapioppo's flood gauge (below) and stay on the bike everywhere: a bell (with its own
  key), a front basket, a dynamo lamp that lights the way at night, a rear rack, a sporty paint job.
- **Villagers ride too:** Pierina on her post round, others along the levee road, and bikes lean on every wall.

## The flood gauge: Boccapioppo's progress meter
Ermes repaints his river gauge with the flood's peak, **7.40 m**. Every request you finish in Boccapioppo brings the
reading down, and he announces it to the centimetre. At 0.00 m the flood is truly over. It replaces the Sindaco's
approval rating here; Monteforchetta keeps its own.

- Main requests bring it down 1.00 m each, side requests 0.50 m, and each returned lost thing 0.10 m. Without the
  finale the reading can't reach zero.
- Rewards are bike upgrades and building unlocks:

| Reading | Milestone | Reward |
| --- | --- | --- |
| 6.40 m | "Down a metre. Don't get excited." | A bicycle bell |
| 5.20 m | "The river's back in its bed." | A front basket, and the mooring plot: a strip of bank beside the houseboat to build on |
| 3.80 m | "Halfway, give or take a centimetre." | A dynamo lamp for night riding, and the plans for the streetlight and electric lamp |
| 2.20 m | "The ducks are back. Well, the coypus." | A rear rack, and the mooring plot grows into a garden with a jetty |
| 0.00 m | "The flood is over." | A sporty paint job in a colour you choose. Needs the finale. |

Names and numbers can change in the build. Plans you already own from Monteforchetta are not given twice.

## The cast
Nine villagers. Ids are `river_town_<first name>`, for example `river_town_ermes`.

| Who | Where | Who they are | Outfit |
| --- | --- | --- | --- |
| **Guardiano Ermes "Centimetro" Vercesi** | His keeper's house on the levee and the gauge post | The river authority's levee warden. Knows the river's level to the centimetre at any hour and announces it unasked. Gruff, kind underneath, talks to the Po like an old rival. Called for the Geometra, puts you straight to work and gives the finale. | Peaked cap, dark oilskin coat, rubber boots, a notebook of 40 years of readings in his pocket |
| **Tullio "Caronte" Maffi** | The bank beside his sunken ferry; the bridge once it's built | The boatman, called "Caronte" after the mythical ferryman because he's rowed people across for 40 years with the same long face. Says six words a day, every one of them wise. Secretly proud of the nickname. Gives the pontoon bridge. | Navy fisherman's sweater, woollen cap, an oar he carries everywhere |
| **Primo "Raggio" Rampoldi** | His bike workshop off the piazza | The bike repairman ("Raggio" means spoke). Raced as an amateur in the 1950s and claims he once dropped a future champion on a climb. Can't stand cars. His workshop is a cave of wheels, and he can fix anything with an inner tube. Rebuilds your bike. | Grey work coat over a striped 1950s cycling jersey, flat cap |
| **Gildo Bergonzi** | His fishing shack on the Po | Old fisherman who saw the monster catfish in 1951 and has talked of little else since. | Waxed jacket, waders, a hat with fishing flies stuck in it |
| **Mattia Bergonzi** | With Gildo, or on the levee | Gildo's teenage nephew. Doesn't believe in the catfish, comes fishing anyway, takes the photo. | Football shirt, baggy jeans, cassette Walkman, bucket hat |
| **Signora Wanda Tacconi**, "la Regina del Liscio" | Her dance hall on stilts; practising steps on the levee | The dance hall's owner, "the queen of ballroom dancing", regional champion in 1968. Still dances everywhere, even on the levee. Dramatic about the flood ("my parquet!") and generous with everyone. | Sequinned cardigan, swirly skirt, dancing shoes, big hair |
| **Rina Daccò**, "la Rina" | Her bar on the piazza | Sharp and quick, runs the card tables with an iron hand and knows every secret before it happens. Serves coffee in rubber boots since the flood. Sells the train tickets. Gives "Pump out the piazza". | Black waistcoat, white blouse, rubber boots |
| **Ines Gandini** | Her sawmill on the east bank | Runs the poplar sawmill her late husband founded. Pencil behind her ear, no patience for wasted wood. | Checked flannel shirt, apron, pencil behind the ear |
| **Pierina Arrigoni** | Her house in town; her post round by bike | The postwoman. Slow and steady, takes all morning because she stops for coffee at every house. Never loses a letter. | Bright yellow jacket and cap (a nod to the post office's colour, with no logo), a big leather post bag, bicycle clips |
| **The player** | | The Geometra from Monteforchetta, sent by the province after the flood. | As in Monteforchetta |

## Gathering
| Material | Where it comes from |
| --- | --- |
| Wood | Chopping poplars in the plantation on the east bank (the chopping minigame). Ines sells wood too. |
| Stone | Big Alpine boulders on the gravel bars of the Alpine river (the quarrying minigame). |
| Clay | The grey flood silt on the floodplain. |
| Sand (`river_town_sand`) | Dug at the Po sandbank. For sandbags. |
| Metal, copper wire | Primo's workshop sells them. |
| Fabric | Empty jute coffee sacks from Rina's bar, which also make good sandbags. |
| Flowers | Late wild asters on the levee bank. |
| Poplar mushrooms (`river_town_pioppino`) | Clumps on old poplar stumps. Rina pays well for them. |
| Fish | The Po: carp, bream, eel and small catfish. The Alpine river: trout and grayling. Junk from both: an old boot, a bicycle wheel, a tyre. Ids like `river_town_carp`. |
| Things the flood took | Villagers' belongings scattered by the water (the shared lost things): six in all, among them a cuckoo clock up a willow, a garden gnome on the sandbank and Wanda's 1968 trophy in the mud. Return them for thanks, gossip and 10 cm off the gauge. |
| Runaway logs (`river_town_log`) | Ines's poplar logs, stranded along the banks by the flood. Her request. |
| Treats | At Rina's bar: sbrisolona (a big crumbly almond cake, broken by hand, never cut), a goose salami sandwich, a paper cone of fried little river fish, and hot zabaglione in a glass. |

## Shops
| Shop | Sells | Buys |
| --- | --- | --- |
| Rina's bar | The four treats, coffee sacks (fabric) | Poplar mushrooms, fish |
| Ines's sawmill | Wood bundles, the Pontoon plans | Runaway logs once her request is done, wood |
| Primo's workshop | Metal, copper wire, spare parts | River junk: boots, bicycle wheels, tyres |

## Requests
Ids are `river_town_<name>`. As everywhere, construction requests check what you built, not one layout. Step details
and amounts below are the plan and can change in the build.

### Main story
| # | Request | Given by | What you do |
| --- | --- | --- | --- |
| 1 | **Straight to Work** | Ermes | He meets the bus with a shovel: fill five sandbags at the sandbank and bring them to the patched breach. His short remarks on the way are the tour: the flood, the piazza, the bridge that isn't there. Coffee at Rina's (everyone stares), then the stranded houseboat where you'll sleep, "dry inside, mostly". |
| 2 | **The Pontoon Bridge** | Tullio | In steps: gather wood, clay to caulk the boats and metal for the chains; walk round over the Roman bridge to buy the Pontoon plans from Ines; build a crossing of pontoons and planks from bank to bank at the bridge site (any continuous, walkable path counts, as with Monteforchetta's road); add railings. Tullio crosses first and says his six words. |
| 3 | **Pump Out the Piazza** | Rina | Her bar is ankle-deep. Gather the parts, then build a waterwheel in the fast Alpine river, carry its power with shafts to a pump beside the piazza's old sump, and run pipes to the outfall through the levee (a machine target, `fed:river_town_outfall`). The piazza drains, and Rina puts the card tables back out. |
| 4 | **Saturday at the Dance Hall** | Wanda | Gather wood, fabric and flowers, then fit out the hall: a dance floor, a stage, lights, a bar counter, seats and a splash of colour (a room checklist). Pierina spreads the word. After 8 PM the town comes to the first dance since the flood: the band plays, the lights come on, villagers gather and sway, and you watch from the bar. |
| 5 | **Close the Breach**, the finale | Ermes | Ermes hands you the Sandbags plans. Fill sandbags (sand and coffee sacks), gather stone, then build a solid wall across the breach from sandbags, stone blocks and foundations, with no gap left. Then the storm night: rain lashes the plain, the Po rises up the gauge, the whole town waits on the levee with Ermes calling out the centimetres, and the levee holds. The gauge reaches zero. |

### Side requests
| Request | Given by | What you do |
| --- | --- | --- |
| **A Bike from the Mud** | Primo | Early, after the first day. He has a flood-wrecked bike and no time. Bring him metal and an old tyre fished out of the river; he rebuilds it overnight. Collect it in the morning and try it on the levee road. The bike is yours, everywhere bikes are allowed. |
| **A Roof That Floats** | Ermes | You sleep in the houseboat stranded on the mud from day one. Patch the hull (wood and clay), build a slipway of planks and posts from the boat down to the backwater (any continuous, supported path counts), and at dawn half the town hauls it down on ropes and it floats at its mooring. Last, make the cabin cosy (a table, somewhere to sit, a lamp, a rug, a painting). |
| **The Monster of the Po** | Gildo and Mattia | Bait from Gildo, a stronger line from Primo, then night fishing at the confluence (after 8 PM). You hook it: an enormous fishing minigame. Mattia takes the photo, and Gildo asks you to let it go, because "what would we talk about then?". The photo hangs in Rina's bar, and nobody believes it. |
| **Ines's Runaway Logs** | Ines | The flood swept her poplar logs downriver. Find six stranded along the banks (in the willows, under the dance hall, against the Roman bridge, on the sandbank) and bring them back. |
| **Pierina's Round** | Pierina | Her wrist is in a sling, so she walks her bike. Once you have yours, do her round: letters to five villagers and an absurd parcel for Wanda. |

Five main and five side requests, plus the lost things.

## Rooms you can walk into
- **The houseboat:** your home, with a bed and a wardrobe from the start. Small: one cabin and the deck.
- **The dance hall:** empty and wrecked until its request.
- **Rina's bar:** card tables, the counter, the payphone, football on a boxy TV. Rina works behind the counter.
- **Primo's workshop:** wheels hanging from the ceiling, a workbench, an old racing poster. He mends bikes inside.
- **Ermes's house:** a desk, a stove, 40 years of logbooks and the telephone to the river authority.
- **Pierina's house:** tidy, with parcels everywhere.
- **Gildo and Mattia's fishing shack:** nets, rods, and a wall of catfish drawings.
- Not the church, the station or the sawmill (an open shed you walk under).

## Look
- **Buildings:** red brick for the church, the station, the sawmill and the farm courtyard. Houses in pale Lombard
  yellow and faded orange plaster with dark green shutters, an arcade along the piazza, curved terracotta roofs. The
  warden's house in the river authority's oxblood red with pale corner stones. The dance hall in white-and-sky-blue
  painted wood on stilts. Fresh tide lines on the walls near the water.
- **Palette:** red brick `#a5523a`, Lombard yellow `#e8c77a`, faded orange `#d9935a`, shutters `#3f5a3a`,
  oxblood `#7a2e2a` with corner stones `#efe6d6`, dance hall `#f4f1ea` and `#8fc0dc`, roofs `#b5653a`.
- **Plants:** poplars in plantation rows and tall Lombardy column poplars along the levee road and the station
  avenue, golden in autumn; silvery willows leaning over both rivers and reed beds in the backwater; thorny black
  locust scrub on the floodplain and the railway embankment; harvested maize stubble north of town with a few
  forgotten cobs; late asters on the levee; poplar mushrooms on old stumps.
- **Ground:** grey flood mud on the floodplain, white pebbles and gravel bars along the Alpine river, the pale Po
  sandbank, grassy levee banks, gravel paths and the piazza's cobbles under the water.
- **Water:** two rivers that look different. The Alpine river is clear blue-green over pebbles and fast; the Po is
  wide, brown and slow. You can see the line where they meet.
- **Animals:** coypus waddling on the banks, cormorants drying their wings on posts and snags, a flock of farm geese
  that chases bicycles, kingfishers flashing blue along the Alpine river, village cats waiting for Gildo's catch.
- **Light:** washed and golden. The storm cleaned the air: crisp, clear days, a low golden sun, long shadows,
  glowing poplars and the Alps sharp on the horizon. A thin mist on the water at dawn only.
- **Weather:** passing autumn showers, and the big storm on the finale night.
- **The look block** (`location.json`): warm golden highlights, slightly cool clear shadows, a little more wind
  than Monteforchetta, falling poplar leaves, few motes, no fireflies (it's late autumn).

## Sound
- **Music:** original, in the game's procedural music system, with a theme for each part of the day. The Po
  valley's dance-hall music: accordion, clarinet and double bass playing waltzes, polkas and mazurkas. A lazy waltz at
  dawn, bouncy polkas by day, a slow tango at night. Thin and quiet while the dance hall is wrecked, fuller once it
  reopens, with its own tune for the first dance.
- **Sounds:** the two rivers (the Alpine river rushing over its pebbles, louder near it; the Po a slow, deep lapping,
  so you can hear which river you're beside), and bicycle bells as villagers pass, with the tick of a freewheel when
  you coast. (The train, animal sounds and church bells were offered and not chosen.)

## Changes to shared code this needs
Each is the smallest general version, comes with a test, and is named at the top of the pull request that makes it.
Toriano plans some of the same changes; whichever session lands one first, the other reuses it after merging main.

| Change | Why | Stage |
| --- | --- | --- |
| **A path check for any zone** (`path:<zone>` alongside the hard-coded `bridge` and `dock`), using today's `Validate.path_across` | The pontoon bridge and the houseboat's slipway. Toriano plans the same. | 3 |
| **A sealed check for a zone** (`sealed:<zone>`: no ground-level gap from one side of the zone to the other) | Closing the breach | 3 |
| **A Pontoon piece** (agreed with the user): a flat-bottomed boat placed on water that floats and holds up deck planks without posts; the walk physics treat its deck like a bridge | The pontoon bridge; usable on any water | 3 |
| **A Sandbags piece** (agreed with the user): a low, stackable wall of sacks that blocks water and walking, costing sand and fabric | The breach; usable anywhere | 3 |
| **The bicycle:** a ride mode in the player controller, a bike model, `"bikes": false` in a map entry, getting off automatically, the upgrades, a save field, a key binding and a gamepad button | A Bike from the Mud; usable everywhere | 3 (may be its own pull request) |
| **A location's own progress meter** (name, unit, milestones, counting up or down), fed by that location's requests | The flood gauge. Toriano plans the same for its column inches. | 3 |
| **What fishing catches, per location**, and a heavier setting for one special fish | The two rivers' fish, the junk, the monster catfish. Toriano plans the per-location catches. | 3 |
| **A request can start a storm** (heavy rain for a while, then back to the normal weather) | The finale | 3 or 4 |
| **Ground paint from the location script** (mud, gravel, sand instead of meadow) | The floodplain and gravel bars. Reuse Toriano's if it has landed. | 1 or 4 |
| **Water tint per area** from the location script | The clear Alpine river against the brown Po | 4 |

Everything else lives in Boccapioppo's own files (`docs/WORLD.md`): `godot/data/locations/river_town/`,
`godot/scripts/locations/river_town.gd` and helpers in `godot/scripts/locations/river_town/`,
`godot/tests/test_river_town.gd` and `godot/tests/play_river_town.gd`. The draining piazza, the houseboat moving to its
mooring, the rising Po on the storm night, the photo in the bar and the debris that clears are location code.

## Build stages
One pull request per stage. Each keeps the game playable and the tests passing.

1. **Ground and map.**
   - The ground shape in `river_town.gd`: the town's low plateau and the lower piazza, the L-shaped levee, the
     floodplain with the backwater and sandbank, the breach, the Alpine river with its gravel bars, the Po, the east
     bank, flowing-water cells for waterwheels.
   - The layout: spawn and arrival at the bus stop, the departure point, the nav graph, paths, build zones (bridge
     site, piazza, dance hall, breach, houseboat mooring), resource nodes and benches.
   - A hidden map entry and a first `look` in `location.json`.
   - Plain boxes for the buildings so the map reads in screenshots.
   - `test_river_town.gd`: a playable world (the arrival is walkable, every nav spot is reachable, water where the
     rivers are, build zones on dry ground or on the water where they should be, the east bank reachable over the
     Roman bridge).
2. **Buildings and scenery.**
   - Models for the houses, the arcade, the bar, Primo's workshop, the church, the station, Ermes's house and the
     gauge post, the dance hall on stilts, the houseboat, Gildo's shack, the sawmill and the farm courtyard; the
     Roman bridge; the sunken ferry and the flood debris.
   - Rooms you can walk into, with furniture and routes.
   - Poplar rows and columns, willows, reeds, black locust, maize stubble; the Alps, plain and hills on the horizon.
3. **People, dialogue and requests.**
   - The nine villagers with schedules, greetings, topics and gifts.
   - The ten requests, the three shops, Boccapioppo's materials, fish and treats, the lost things and the flood gauge.
   - The shared changes listed above for this stage, the bicycle among them.
   - `play_river_town.gd`: a scripted playthrough of every request with real input.
4. **Look and ambient life.**
   - Tuning the look block, the two waters, the finale's storm and rising river, the piazza draining.
   - Coypus, cormorants, geese, kingfishers and cats; villagers on bicycles.
   - The accordion themes and the river and bicycle sounds; the cast's outfits.

## Agreements needed with other sessions
- **Monteforchetta:** the flag that opens the bus line, which reveals Boccapioppo on the travel map.
- **The Alpine village:** the valley railway between the two, with Boccapioppo's station at the bottom.
- **Toriano:** the shared path check, progress meter, fishing catches and ground paint. Whoever lands one first, the
  other reuses it.

## Risks
- **The bicycle touches everyone.** It changes the shared player controller. It comes with tests, and every existing
  playthrough is run before its pull request, so walking stays exactly as it was when you're not riding.
- **The houseboat moves** from the mud to its mooring, and its room moves with it. If that fights the interiors
  code, the fallback is that it is pulled level where it lies and floats when the finale's storm raises the water.
- **Parallel shared changes** with Toriano. Merging main often keeps the two from colliding.

## Build status
What exists now, and the choices made while building that the design above didn't settle.

**Stage 1, the ground and the map** (merged):
- The ground shape is code in `godot/scripts/locations/river_town.gd`, and the map is `godot/data/locations/river_town/layout.json`.
- The map is land on every side, so irrigation ditches along the north, west and east edges and the Po along the
  south keep you on it. Beyond the edge lies flat far land.
- The levee is 2.8 m high, with the breach as a walkable gap.

**Stage 2, the buildings and scenery** (merged):
- **Models** are in `godot/scripts/locations/river_town/models.gd`: houses with balconies and green shutters, Rina's bar with
  its awning and payphone, the arcade's covered walk, the brick church with its bell tower and clock, Primo's
  workshop, Ermes's keeper's house, the station, the farm courtyard, the houseboat, the shack, the dance hall and the
  sawmill's office. Walls near the water carry the flood's tide line.
- **Rooms you can walk into:** the houseboat (bed and wardrobe), the dance hall (empty), the bar, Primo's workshop,
  Ermes's house, Pierina's house and the shack. Rina, Primo, Ermes, Pierina and Gildo have a spot to work at.
- **Ermes's house** stands at the landward foot of the levee, not on its crest. The shared indoor camera expects a
  room's floor near ground level.
- **The dance hall's floor** is a raised platform in the ground shape, so you really walk on it. A lattice skirt
  and stilts hide the platform's sides, and you reach it by a ramp from the west.
- **The sawmill** is a small brick office beside an open shed you walk under.
- **Trees** are drawn by the location script. Their trunks are invisible solid props in the layout (`river_town_tree`),
  so they block you like any tree. The kinds are hybrid poplars in a plantation grid, Lombardy column poplars along the
  station avenue and beyond the ditches, white willows, black locust and a few big shade trees. The eight chopping
  trees look like plantation poplars.
- **Scenery** is in `godot/scripts/locations/river_town/scenery.gd`:
  - The Roman bridge, the sawmill's shed and log piles, the station's track, the river gauge post and the bus stop.
  - The flood's leftovers: the flooded piazza, mud, the sunken ferry, a car on its roof, a fridge, a bathtub, the
    sandbag patch and debris against the bridge.
  - Leaning bicycles, reeds and maize stubble.
  - The horizon: the Alps, lines of poplars, other villages' bell towers and the Apennine hills.
- **The flooded piazza** is a water surface named `river_town_pond`, which stage 3 hides when the piazza drains.
- **Paved ground** uses the shared `ground` list in the layout, which keeps greenery off: setts in the piazza, slabs
  under the arcade's covered walk and on the station platform, and gravel in the sawmill yard.
- **The travel map** shows Boccapioppo once its `reveal` flag (`river_town_revealed`) is set. Monteforchetta's
  city-bus finale sets it (in that session's next pull request).

**Stage 3a, shared tools** (merged): the zone path and sealed checks, the Pontoon and Sandbags pieces, what a node
gives, fishing catches per location, a request's own weather and a location's own progress meter.

**Stage 3b, people, dialogue and requests** (merged). The bicycle, "A Bike from the Mud" and "Pierina's Round" come
in stage 3c.
- **The people** are in `npcs.json`. Each has days that follow the story: ordinary days, then the evenings at the
  dance hall once it's fitted out, the storm night on the levee by the breach, and back to normal after it. Ermes
  waits at the bus stop until he has welcomed you, and reads his gauge at dawn every morning.
- **Homes:** Wanda, Tullio and Ines sleep in three of the town houses, which you can now walk into. Ines lives in
  town and walks to the sawmill over the Roman bridge, or over your pontoon bridge once it's built.
- **The requests** are in `quests.json`: the five main ones, "A Roof That Floats", "The Monster of the Po", "Ines's
  Runaway Logs" and six lost things.
  - **Pump Out the Piazza** changed in the build. A pump by the sump can't be powered from the river, because
    shafts don't connect over the 2.8 m levee. Instead, the old drainage pumping house of 1934 stands on the
    levee's river side, beside a stone quay. A waterwheel in the Alpine river by the quay and shafts across the quay
    turn its drive (`fed:river_town_pump`), and its pipe under the levee drains the piazza.
  - **The Pontoon plans** are a gift from Ines in the bridge request, so you don't buy them.
  - **The dance:** after 8 PM the villagers stand round the dance floor. Real dancing animations come in stage 4.
  - **The storm night** is three steps: Ermes waits on the levee once the wall stands, the storm comes after 8 PM,
    and the river peaks past midnight.
  - **The monster** bites at the meeting of the rivers after dark once Primo has given you his line. It leaves a
    whisker on your line, and you show it to Mattia, waking him if you have to.
  - **The lost things:** Mattia's Walkman replaced Ermes's logbook, so that all nine villagers give you something.
- **The flood gauge** is the shared location meter (`location.json`): a metre per main request, half a metre per
  side request, ten centimetres per lost thing. Its milestones give the mooring plot (`river_town_plot`), the
  streetlight and electric lamp plans, and the mooring garden with a jetty (`river_town_garden`). The bike upgrades
  join them in stage 3c. Until then the gauge stops at 0.30 m.
- **The story changes the place.** `river_town.gd` lists `WORLD_FLAGS`. When one is set, the world is built again
  where you stand once the conversation ends:
  - the piazza's pond goes once it's drained;
  - the dance hall is scrubbed, mended and lit after its first dance;
  - on the storm night the rivers rise to the brim;
  - after the storm the junk and the old sandbag patch are cleared;
  - the catfish photo hangs in Rina's bar.
  - When the houseboat is launched, she moves to her mooring in the backwater, with a jetty and a gangway at her
    door. Her cabin is cleared of the flood's junk for you to furnish (`river_town_cabin`).
- **The bus line:** Close the Breach reveals Casalrana (`rice_village_revealed`), the next stop on the bus line.
- **Villagers cross your bridge:** the layout's `crossings` let them walk the path you built across the pontoon
  bridge.

**Stage 3b, fixes from playing every request** (merged). The full playthrough of every request found these, now
fixed:
- **The ferry landing:** the last strip of bank before the Alpine river was 0.46 m below the floodplain, just over
  what a walkable path may step down, so a row of pontoons never joined the west bank. The bank now eases down to
  the water where the pontoon bridge starts. A test builds the bridge and the houseboat's slipway and checks both make
  a walkable path.
- **Mattia's bed:** he and Gildo slept on the same spot, and then, inside the door, he blocked the way in to his
  uncle. He now sleeps in his own corner of the shack. A test checks that no two villagers share a spot at the same
  hour.
- **Paths:** two path spots run along the dance hall's east side and one reaches the sandbank, so villagers (and
  the playthrough) don't head for the nearest spot inside the hall. One runaway log moved from under the hall's east
  edge to beside it.
- **The dance hall** asks for 15 wood, what its cheapest fit-out costs (changed by the Monteforchetta session when a
  new shared test caught it).
- **The playthrough** starts as if you had come by Monteforchetta's bus with its main story done
  (`arrive_as_if_played(["hearthglow"])`), and keeps a checkpoint after each request (`--from=` and `--to=`).

**Stage 3c, the bicycle** (merged):
- **The bicycle is shared** (`Bicycle`, `BikeModel`, and a ride mode in the player controller). `F` gets on and off,
  `H` rings the bell, and with the paint job `T` repaints it while you ride. It's a little under twice running speed,
  steadier in the turns and leaning into them, and it doesn't hop. You get off by yourself to talk, build, gather or
  sleep, indoors and on stairs. A place's map entry can say `"bikes": false`.
- **Owning it and its upgrades are story flags** (`hasBike`, `bikeBell`, `bikeBasket`, `bikeLamp`, `bikeRack`,
  `bikePaint`), so requests and meter milestones give them with what they already have. The flood gauge's
  milestones give the five upgrades in the order the design lists. The dynamo lamp lights the way only while you ride
  at night.
- **A Bike from the Mud** (Primo): 2 metal (his shop, or the rusty boulder on the gravel bar) and an old tyre
  fished out of the Alpine river by the town (once he's asked, a tyre bites there). Hand them over in the afternoon or
  evening, collect the bike the next morning, and ride it 25 m along the levee road.
- **Pierina's Round:** five letters (Ermes, Tullio, Gildo, Ines, Rina) and a tuba-shaped parcel for Wanda.
- **The gauge** now reaches 0.00 m with every request done, and can't without the finale.
- **Villagers on bicycles** come with the look and ambient life, in stage 4.

**Stage 4a, the look** (this pull request, with 4b and 4c). Stage 4 comes in three parts: the look (4a), the animals and villagers on
bicycles (4b), and the music, sounds and outfits (4c).
- **The ground is painted** (`paint()` in `river_town.gd`): grey flood mud on the floodplain, with grass coming back
  in patches, silt and a dark tide mark on the levee's outer slope up to where the flood came, white pebbles along
  the Alpine river, the Po's pale sandbank and muddy bank, maize stubble north-west of town, ballast on the railway,
  silt fanning into the lower town from the breach, and autumn grass everywhere else. Grass tufts, flowers and bushes
  grow only where the paint says meadow. The far land past the map's edge is a patchwork of fields.
- **Two waters** (a new shared hook, `water_tint(x, z)`): the Alpine river runs clear blue-green over its pebbles, the
  Po wide and brown, and you can see the line where they meet, the clear plume bending downstream along the Po's
  bank. The backwater, the canals and the piazza's sump are still and green-brown.
- **The look block:** warm golden highlights and slightly cool shadows, a lower autumn sun for long shadows, golden
  poplar leaves falling, and clear blue-green water colours for the Alpine river.
- **A thin mist on the water at dawn only**, gone by half past nine (`river_town/mist.gd`).

**Stage 4b, ambient life** (this pull request):
- **Villagers on bicycles** (a small shared change: `"bike"` in a villager's npcs.json entry, `Bicycle.villager_rides`,
  and the villager walker). Pierina rides her blue post bike with basket and rack, Primo his old green racer, Mattia,
  Ines and Wanda theirs. They ride on long routes outdoors, get off near where they're going, indoors and on stairs,
  and ring the bell riding past you.
- **Animals** (`river_town/animals.gd`): coypus waddle along the banks of the backwater, the Po and the canals, and
  slip into the water when you come close, surfacing later. Cormorants dry their wings on snags in the Po and fly a
  loop if you come near. The farm's geese peck about outside the gate and come after you, necks out, if you ride past
  on your bike. Kingfishers sit on willow twigs over the Alpine river and dart along it, low over the water. Cats
  wait by Gildo's shack and the fishing spot for his catch, and outside Rina's bar (the shared cats: pet them).

**Stage 4c, music, sounds and outfits** (this pull request):
- **The dance-hall music** (Boccapioppo's own songs in `location.json`): a lazy waltz at dawn, bouncy polkas by day, a
  mazurka in the evening and a slow tango at night, played on an accordion, a clarinet and a double bass. Thin and quiet
  while the dance hall is wrecked (the melody and the bass), fuller once it reopens, and then the hall's own waltz in
  the evenings. This needed three new shared instruments, bars of other lengths (`bar`, for 3/4) and music that changes
  with a story flag (`"when"`).
- **The two rivers** (`river_town/sounds.gd`): the Alpine river rushing bright over its pebbles, louder as you get
  near it; the Po a low, slow hiss with water lapping at the bank. You can hear which one you're beside.
- **Bicycles:** villagers ring their bell riding past you (4b), and your freewheel ticks when you stop pedalling
  (shared). The geese honk when they come after you.
- **The cast's outfits:** Ermes in his warden's oilskin and peaked cap, Primo in his grey work coat, Mattia in jeans
  with his Walkman, Rina in a black waistcoat over a white blouse, Ines in a red shirt and a sawmill apron, Pierina in
  yellow with her old leather post bag. Three of these are Boccapioppo's own clothes (`appearance.json`): Ermes, Ines
  and Pierina give you one each when you become good friends (6 hearts).

## Checks for every stage
`godot/run_tests.sh`, `npm test` and `npm run build`; screenshots of Boccapioppo in both renderers
(`--island=river_town`); from stage 3, the scripted playthrough of its requests. Each pull request says what was
verified in play and what was only unit-tested.
